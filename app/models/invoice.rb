class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :recipient_company, class_name: "Company", optional: true
  belongs_to :sale_from, class_name: "Company", optional: true
  belongs_to :original_invoice, class_name: "Invoice", foreign_key: :credit_note_original_invoice_id, optional: true
  belongs_to :subscription, optional: true

  # Recurring invoice relationships
  # Parent invoice is the original invoice created for a recurring subscription
  belongs_to :recurring_parent_invoice, class_name: "Invoice", optional: true
  # Sub-invoices are monthly invoices linked to the parent
  has_many :recurring_sub_invoices, class_name: "Invoice", foreign_key: :recurring_parent_invoice_id, dependent: :restrict_with_error

  belongs_to :ship_from_location, class_name: "Location", optional: true
  belongs_to :remit_to_location, class_name: "Location", optional: true
  belongs_to :tax_representative_location, class_name: "Location", optional: true
  has_many :credit_notes, class_name: "Invoice", foreign_key: :credit_note_original_invoice_id
  has_many :tax_submissions
  has_many_attached :attachments

  after_update :sync_archived_status, if: :saved_change_to_archived?

  # Explicitly declare attribute types for enums to prevent 'Undeclared attribute type' errors in some contexts
  attribute :invoice_type, :string
  enum invoice_type: { sale: "sale", purchase: "purchase" }
  attribute :invoice_category, :string, default: "standard"
  enum invoice_category: { standard: "standard", credit_note: "credit_note", quote: "quote" }

  before_validation :normalize_subscription_end_dates

  validate :attachments_type_allowed
  validate :line_items_tax_selected
  validate :credit_note_number_required
  validate :invoice_number_unique_per_user
  validate :invoice_numbering_structure_valid
  validate :monthly_charge_dates_valid

  def line_items
    line_items_data || []
  end

  def grand_total
    total["grand_total"].to_f
  end

  # Generate next invoice number for user
  # Format: YYYY-00001-XXX for parent invoices (e.g., 2026-00001-009)
  # Recurring sub-invoices use parent number with sequence (e.g., 2026-00001-009-01, 2026-00001-009-02)
  def self.next_invoice_number_for_user(user, type = "sale", category = "standard", parent_invoice: nil)
    # For sub-invoices of recurring billing, use parent invoice number with sequence
    if parent_invoice.present? && parent_invoice.recurring_parent_invoice_id.nil?
      return next_recurring_sub_invoice_number(parent_invoice)
    end

    # For regular invoices, use standard numbering
    last_number = user.invoices.where(invoice_type: type, invoice_category: category)
                       .where(recurring_parent_invoice_id: nil)
                       .where.not(invoice_number: [nil, ""])
                       .order(:created_at).pluck(:invoice_number).last
    return (category == 'quote' ? "Q-000-001" : "000-001") unless last_number

    if last_number =~ /\d+$/
      prefix = last_number.gsub(/\d+$/, "")
      num = last_number.match(/(\d+)$/)[1].to_i + 1
      "#{prefix}#{num.to_s.rjust(3, '0')}"
    else
      "#{last_number}-001"
    end
  end

  # Generate the next sub-invoice number for a parent invoice
  # e.g., if parent is "2026-00001-009", returns "2026-00001-009-01", "2026-00001-009-02", etc.
  def self.next_recurring_sub_invoice_number(parent_invoice)
    raise "Cannot generate sub-invoice number for non-parent invoice" unless parent_invoice.recurring_parent_invoice_id.nil?

    # Count existing sub-invoices to determine sequence number
    sub_invoice_count = parent_invoice.recurring_sub_invoices.count + 1
    parent_number = parent_invoice.invoice_number
    
    "#{parent_number}-#{sub_invoice_count.to_s.rjust(2, '0')}"
  end

  # Check if this invoice is a parent recurring invoice
  def recurring_parent_invoice?
    subscription_id.present? && recurring_parent_invoice_id.nil?
  end

  # Check if this invoice is a sub-invoice of a recurring billing
  def recurring_sub_invoice?
    recurring_parent_invoice_id.present?
  end

  # Check if this invoice has subscription line-items
  def has_subscription_line_items?
    return false if line_items_data.blank?

    line_items_data.any? do |item|
      item.is_a?(Hash) && item['optional_fields'].is_a?(Hash) && 
      item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
    end
  end

  # Get subscription line-items from this invoice
  def subscription_line_items
    return [] unless line_items_data.present?

    line_items_data.select do |item|
      item.is_a?(Hash) && item['optional_fields'].is_a?(Hash) && 
      item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
    end
  end

  # Check if this invoice is a subscription contract (parent invoice)
  def subscription_contract?
    has_subscription_line_items? && recurring_parent_invoice_id.nil?
  end

  # Check if this invoice is a generated subscription invoice (child)
  def subscription_invoice?
    billing_reference.present? && !has_subscription_line_items?
  end

  # Check if subscription is active (not archived, has subscription line items)
  # The end_date represents the end of the CURRENT billing period, not the overall subscription expiry.
  # A subscription remains active as long as it's not archived.
  def subscription_active?(on_date = Date.current)
    return false unless subscription_contract?
    return false if archived?

    subscription_line_items.any? do |item|
      start_date = extract_subscription_field(item, 'start_date')
      billing_cycle = extract_subscription_field(item, 'billing_cycle')
      start_date.present? && billing_cycle.present?
    end
  rescue
    false
  end

  # Check if subscription is due for billing
  # Due when on_date >= end_date (the current billing period has elapsed)
  def subscription_due_for_billing?(on_date = Date.current)
    return false unless subscription_active?(on_date)

    subscription_line_items.any? do |item|
      end_date = extract_subscription_field(item, 'end_date')
      end_date.present? && Date.parse(end_date) <= on_date
    end
  rescue
    false
  end

  # Generate subscription invoices for all elapsed billing periods up to on_date.
  # For example, if billing is monthly, start_date is May 29, end_date is June 29,
  # and on_date is August 29, this generates invoices for June 29 and July 29 periods.
  # Returns an array of all generated invoices.
  def generate_subscription_invoices(on_date = Date.current)
    raise "Cannot generate invoice: not a subscription contract" unless subscription_contract?
    raise "Cannot generate invoice: subscription not active" unless subscription_active?(on_date)
    raise "Cannot generate invoice: not due for billing" unless subscription_due_for_billing?(on_date)

    generated_invoices = []

    # Keep generating invoices while the subscription is due for billing
    while subscription_due_for_billing?(on_date)
      invoice = generate_single_subscription_invoice
      generated_invoices << invoice
      reload # Reload to get updated line_items_data with new end_date
    end

    generated_invoices
  end

  # Generate the next single subscription invoice (one billing period)
  def generate_subscription_invoice(on_date = Date.current)
    raise "Cannot generate invoice: not a subscription contract" unless subscription_contract?
    raise "Cannot generate invoice: subscription not active" unless subscription_active?(on_date)
    raise "Cannot generate invoice: not due for billing" unless subscription_due_for_billing?(on_date)

    generate_single_subscription_invoice
  end

  private def generate_single_subscription_invoice
    # Generate sub-invoice number
    new_invoice_number = Invoice.next_recurring_sub_invoice_number(self)

    # Create new line items with updated end dates (advance to next billing period)
    new_line_items_data = line_items_data.map do |item|
      if item.is_a?(Hash) && item['optional_fields'].is_a?(Hash) &&
         item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }

        billing_cycle = extract_subscription_field(item, 'billing_cycle')
        current_end_date = extract_subscription_field(item, 'end_date')

        if billing_cycle && current_end_date
          new_end_date = calculate_next_period_date(Date.parse(current_end_date), billing_cycle)
          new_start_date = current_end_date # New period starts where old one ended
          new_item = item.deep_dup

          subscription = new_item['optional_fields']['subscription']
          if subscription.is_a?(Hash)
            end_key = subscription.keys.find { |k| k.to_s.include?('end_date') }
            start_key = subscription.keys.find { |k| k.to_s.include?('start_date') }
            subscription[end_key] = new_end_date.to_s if end_key
            subscription[start_key] = new_start_date.to_s if start_key
          end

          new_item
        else
          item
        end
      else
        item
      end
    end

    # Create the new invoice
    new_invoice = user.invoices.build(
      recipient_company: recipient_company,
      sale_from: sale_from,
      invoice_type: invoice_type,
      invoice_category: invoice_category,
      issue_date: Date.current,
      invoice_number: new_invoice_number,
      currency: currency,
      line_items_data: line_items_data, # The child gets the CURRENT period's line items
      recipient_note: recipient_note,
      payment_terms: payment_terms,
      price_adjustments: price_adjustments,
      billing_reference: self.invoice_number,
      recurring_parent_invoice_id: id,
      recurring_sequence_number: recurring_sub_invoices.count + 1
    )

    if new_invoice.save
      # Advance the parent invoice's line items to the NEXT billing period
      update_columns(line_items_data: new_line_items_data)
      new_invoice
    else
      raise "Failed to generate subscription invoice: #{new_invoice.errors.full_messages.join(', ')}"
    end
  end

  # Calculate next period date based on billing cycle
  def calculate_next_period_date(from_date, cycle)
    case cycle
    when 'monthly'
      from_date >> 1
    when 'quarterly'
      from_date >> 3
    when 'annual'
      from_date >> 12
    else
      from_date >> 1 # Default to monthly
    end
  end

  # Extract subscription field from line item
  def extract_subscription_field(line_item, field_name)
    return nil unless line_item.is_a?(Hash) && line_item['optional_fields'].is_a?(Hash)
    
    subscription = line_item['optional_fields']['subscription']
    return nil unless subscription.is_a?(Hash)
    
    subscription.find do |key, value|
      key.to_s.include?(field_name)
    end&.last
  end

  # Scope for finding subscription invoices due for billing
  scope :subscription_contracts_due_for_billing, ->(date = Date.current) {
    where(recurring_parent_invoice_id: nil)
      .where(archived: false)
      .where.not(line_items_data: nil)
  }

  # Scope for finding all subscription contracts
  scope :subscription_contracts, -> {
    where(recurring_parent_invoice_id: nil)
  }

  # Scope for finding subscription invoices (generated invoices)
  scope :subscription_invoices, -> {
    where.not(billing_reference: nil)
  }

  def sender_company
    sale_from || user&.company
  end

  def sender_user
    sender_company&.user || user
  end

  def has_associated_credit_note?
    return false unless standard?

    Invoice.exists?(
      user_id: user_id,
      invoice_number: invoice_number,
      invoice_type: invoice_type,
      sale_from_id: sale_from_id,
      invoice_category: "credit_note"
    )
  end

  def contextual_original_invoice
    return nil unless credit_note?
    
    # First try the direct association if it belongs to the same user
    return original_invoice if original_invoice.present? && original_invoice.user_id == user_id
    
    # Otherwise find by criteria in the same user's scope
    Invoice.find_by(
      user_id: user_id,
      invoice_number: invoice_number,
      invoice_type: invoice_type,
      sale_from_id: sale_from_id,
      invoice_category: "standard"
    )
  end


  def normalize_subscription_end_dates
    return if line_items_data.blank?

    line_items_data.each do |item|
      next unless item.is_a?(Hash)
      optional_fields = item['optional_fields']
      next unless optional_fields.is_a?(Hash)

      subscription = optional_fields['subscription']
      next unless subscription.is_a?(Hash)

      billing_cycle_key = subscription.keys.find { |k| k.to_s.include?('billing_cycle') }
      billing_cycle = subscription[billing_cycle_key] if billing_cycle_key

      start_date_key = subscription.keys.find { |k| k.to_s.include?('start_date') }
      start_date = subscription[start_date_key] if start_date_key

      next if billing_cycle.blank? || start_date.blank?

      expected_end_date = expected_end_date_for(start_date, billing_cycle)
      next unless expected_end_date

      end_date_key = subscription.keys.find { |k| k.to_s.include?('end_date') } || 'end_date'
      current_end_date = subscription[end_date_key]

      if current_end_date.blank?
        subscription[end_date_key] = expected_end_date
      end
    end
  end

  def expected_end_date_for(start_date_str, billing_cycle)
    start_date = if start_date_str.is_a?(Date)
                   start_date_str
                 else
                   Date.parse(start_date_str) rescue nil
                 end
    return nil unless start_date

    months = case billing_cycle.to_s
             when 'monthly' then 1
             when 'quarterly' then 3
             when 'annual' then 12
             else nil
             end
    return nil unless months

    (start_date >> months).strftime('%Y-%m-%d')
  end

  # Validate that invoice numbers are unique per user
  # Prevents duplicate invoice numbers within same user's invoices
  def invoice_number_unique_per_user
    return if invoice_number.blank?
    
    existing = Invoice.where(user_id: user_id, invoice_number: invoice_number)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:invoice_number, "has already been used for this user")
    end
  end

  # Validate that recurring sub-invoice numbering follows the correct format
  # Parent: YYYY-00001-009, Sub-invoices: YYYY-00001-009-01, YYYY-00001-009-02, etc.
  def invoice_numbering_structure_valid
    return if invoice_number.blank? || invoice_category != 'standard'
    
    if recurring_sub_invoice? && recurring_parent_invoice.present?
      parent_number = recurring_parent_invoice.invoice_number
      expected_prefix = "#{parent_number}-"
      
      unless invoice_number.start_with?(expected_prefix)
        errors.add(:invoice_number, "sub-invoice must follow parent number format (#{expected_prefix}XX)")
      end
      
      # Validate sequence number format (should be 01, 02, 03, etc.)
      sequence_part = invoice_number.sub(expected_prefix, "")
      unless sequence_part =~ /^\d{2}$/
        errors.add(:invoice_number, "sub-invoice sequence must be two digits (01, 02, 03, etc.)")
      end
    end
  end

  private

  def line_items_tax_selected
    return if line_items_data.blank?

    line_items_data.each_with_index do |item, index|
      if item["tax"].blank? || item["tax"].to_s.strip.empty?
        errors.add(:base, "Tax must be selected for line item #{index + 1}")
      end
    end
  end

  def credit_note_number_required
    return unless invoice_category == 'credit_note'
    
    if invoice_number.blank? || invoice_number.to_s.strip.empty?
      errors.add(:invoice_number, "Credit note number is required")
    end
  end

  def sync_archived_status
    tax_submissions.each do |submission|
      submission.update(archived: archived) if submission.archived != archived
    end
  end

  def attachments_type_allowed
    return unless attachments.attached?

    allowed_types = [ "application/pdf", "image/jpeg", "image/png" ]

    attachments.each do |file|
      unless allowed_types.include?(file.blob.content_type)
        errors.add(:attachments, "must be PDF or image files (JPEG, PNG).")
      end
    end
  end

  def monthly_charge_dates_valid
    return unless price_adjustments.present?

    price_adjustments.each_with_index do |adjustment, index|
      next unless adjustment['type'] == 'monthly_charge'

      start_date = adjustment['charge_start_date']
      end_date = adjustment['charge_end_date']

      if start_date.blank?
        errors.add(:price_adjustments, "at index #{index + 1}: Monthly charge must have a start date")
      end

      if end_date.blank?
        errors.add(:price_adjustments, "at index #{index + 1}: Monthly charge must have an end date")
      end

      if start_date.present? && end_date.present?
        begin
          start = Date.parse(start_date)
          end_d = Date.parse(end_date)

          if start >= end_d
            errors.add(:price_adjustments, "at index #{index + 1}: Monthly charge end date must be after start date")
          end
        rescue Date::Error
          errors.add(:price_adjustments, "at index #{index + 1}: Invalid date format for monthly charge")
        end
      end
    end
  end
end
