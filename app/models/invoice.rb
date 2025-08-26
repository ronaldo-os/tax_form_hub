class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :recipient_company, class_name: 'Company', optional: true
  belongs_to :recurring_origin_invoice, class_name: "Invoice", optional: true
  has_many :recurring_invoices, class_name: "Invoice", foreign_key: :recurring_origin_invoice_id
  has_many_attached :attachments

  enum invoice_type: { sale: 'sale', purchase: 'purchase' }

  validate :attachments_type_allowed

  def line_items
    line_items_data || []
  end



  private

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
