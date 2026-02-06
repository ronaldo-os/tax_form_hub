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
  validate :credit_note_amount_within_balance, if: :credit_note?

  def line_items
    line_items_data || []
  end

  def grand_total
    total["grand_total"].to_f
  end

  def total_credited
    credit_notes.sum { |cn| cn.grand_total }
  end

  def remaining_balance
    [grand_total - total_credited, 0].max
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

  def credit_note_amount_within_balance
    return unless original_invoice
    
    # When updating an existing credit note, we need to exclude its own amount from the calculation
    other_credit_notes_total = original_invoice.credit_notes.where.not(id: id).sum { |cn| cn.grand_total }
    available_balance = original_invoice.grand_total - other_credit_notes_total
    
    if grand_total > available_balance
      errors.add(:base, "Credit note total (#{grand_total}) cannot exceed the remaining balance of the original invoice (#{available_balance.round(2)})")
    end
  end
end
