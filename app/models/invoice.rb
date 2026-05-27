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

  before_validation :normalize_subscription_renewal_dates

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

  # Calculate prorated discounts for all subscription additions in this invoice
  # @return [Array<Hash>] Array of proration calculations with line item references
  def calculate_prorated_discounts
    ProrationService.calculate_invoice_prorations(line_items_data)
  end

  # Build discount breakdown for display under line items
  # @return [Hash] Hash mapping line item indices to their discount breakdowns
  def discount_breakdown
    @discount_breakdown ||= ProrationService.build_discount_breakdown(line_items_data)
  end

  # Check if invoice has any prorated subscription additions
  # @return [Boolean]
  def has_prorated_additions?
    discount_breakdown.present?
  end

  # Calculate total discount amount from prorations
  # @return [Float] Total discount amount
  def total_prorated_discount
    calculate_prorated_discounts.sum { |p| p[:discount_amount].to_f }
  end

  # Regenerate prorated calculations - call when line items change
  # This updates the pro_rated_discount field in subscription_addition optional fields
  def regenerate_proration_calculations
    return unless line_items_data.present?

    normalize_subscription_renewal_dates
    prorations = calculate_prorated_discounts

    # Update line_items_data with calculated discounts
    prorations.each do |proration|
      # Find the addition line item by index
      addition_index = proration[:addition_line_item_index]
      addition_item = line_items_data[addition_index]

      next unless addition_item && addition_item['optional_fields']

      # Find the specific subscription_addition group
      addition_item['optional_fields'].each do |group_key, fields|
        next unless group_key.to_s.start_with?('subscription_addition')

        # Update the pro_rated_discount field if it exists in this group
        discount_key = fields.keys.find { |k| k.include?('pro_rated_discount') }
        if discount_key.present?
          fields[discount_key] = proration[:discount_amount].to_s
        end

        # Update the pro_rated_amount field if it exists
        amount_key = fields.keys.find { |k| k.include?('pro_rated_amount') }
        if amount_key.present?
          fields[amount_key] = proration[:pro_rated_price].to_s
        end
      end

      # Update the line item price and quantity for the addition
      addition_item['price'] = proration[:pro_rated_price].to_s
      addition_item['quantity'] = proration[:accounts_added].to_s
    end

    # Mark for update if needed
    self.line_items_data_will_change! if has_changes_to_save?
  end

  def normalize_subscription_renewal_dates
    return if line_items_data.blank?

    line_items_data.each do |item|
      next unless item.is_a?(Hash)
      optional_fields = item['optional_fields']
      next unless optional_fields.is_a?(Hash)

      subscription = optional_fields['subscription']
      next unless subscription.is_a?(Hash)

      billing_cycle = subscription['billing_cycle']
      start_date = subscription['start_date']
      next if billing_cycle.blank? || start_date.blank?

      expected_renewal_date = expected_renewal_date_for(start_date, billing_cycle)
      next unless expected_renewal_date

      renewal_date_key = subscription.keys.find { |k| k.to_s.include?('renewal_date') } || 'renewal_date'
      current_renewal_date = subscription[renewal_date_key]

      if current_renewal_date.blank? || current_renewal_date.to_s != expected_renewal_date
        subscription[renewal_date_key] = expected_renewal_date
      end
    end
  end

  def expected_renewal_date_for(start_date_str, billing_cycle)
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
