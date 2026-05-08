class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :recipient_company, class_name: "Company", optional: true
  belongs_to :sale_from, class_name: "Company", optional: true
  belongs_to :original_invoice, class_name: "Invoice", foreign_key: :credit_note_original_invoice_id, optional: true

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

  validate :attachments_type_allowed
  validate :line_items_tax_selected
  validate :credit_note_number_required

  def line_items
    line_items_data || []
  end

  def grand_total
    total["grand_total"].to_f
  end

  def self.next_invoice_number_for_user(user, type = "sale", category = "standard")
    last_number = user.invoices.where(invoice_type: type, invoice_category: category).where.not(invoice_number: [nil, ""]).order(:created_at).pluck(:invoice_number).last
    return (category == 'quote' ? "Q-000-001" : "000-001") unless last_number

    if last_number =~ /\d+$/
      prefix = last_number.gsub(/\d+$/, "")
      num = last_number.match(/(\d+)$/)[1].to_i + 1
      "#{prefix}#{num.to_s.rjust(3, '0')}"
    else
      "#{last_number}-001"
    end
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

    prorations = calculate_prorated_discounts

    # Update line_items_data with calculated discounts
    prorations.each do |proration|
      index = proration[:line_item_index]
      item = line_items_data[index]
      next unless item && item['optional_fields']

      # Find the specific subscription_addition group
      item['optional_fields'].each do |group_key, fields|
        next unless group_key.to_s.start_with?('subscription_addition')

        # Update the pro_rated_discount field if it exists in this group
        discount_key = fields.keys.find { |k| k.include?('pro_rated_discount') }
        if discount_key.present?
          fields[discount_key] = proration[:discount_amount].to_s
        end
      end
    end

    # Mark for update if needed
    self.line_items_data_will_change! if has_changes_to_save?
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
end
