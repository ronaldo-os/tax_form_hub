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
