class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :recipient_company, class_name: 'Company', optional: true
  belongs_to :sale_from, class_name: 'Company', optional: true
  belongs_to :recurring_origin_invoice, class_name: "Invoice", optional: true
  belongs_to :original_invoice, class_name: 'Invoice', foreign_key: :credit_note_original_invoice_id, optional: true
  
  belongs_to :ship_from_location, class_name: "Location", optional: true
  belongs_to :remit_to_location, class_name: "Location", optional: true
  belongs_to :tax_representative_location, class_name: "Location", optional: true
  has_many :recurring_invoices, class_name: "Invoice", foreign_key: :recurring_origin_invoice_id
  has_many :credit_notes, class_name: 'Invoice', foreign_key: :credit_note_original_invoice_id
  has_many :tax_submissions
  has_many_attached :attachments

  after_update :sync_archived_status, if: :saved_change_to_archived?

  enum invoice_type: { sale: 'sale', purchase: 'purchase' }
  enum invoice_category: { standard: 'standard', credit_note: 'credit_note', quote: 'quote' }
  
  validates :credit_note_original_invoice_id, presence: true, if: :credit_note?
  validate :attachments_type_allowed
  validates :credit_note_original_invoice_id, presence: true, if: :credit_note?
  validate :attachments_type_allowed

  def line_items
    line_items_data || []
  end

  def grand_total
    total["grand_total"].to_f
  end

  private

  def sync_archived_status
    tax_submissions.each do |submission|
      submission.update(archived: archived) if submission.archived != archived
    end
  end

  def attachments_type_allowed
    return unless attachments.attached?

    allowed_types = ["application/pdf", "image/jpeg", "image/png"]

    attachments.each do |file|
      unless allowed_types.include?(file.blob.content_type)
        errors.add(:attachments, "must be PDF or image files (JPEG, PNG).")
      end
    end
  end
end
