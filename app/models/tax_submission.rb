class TaxSubmission < ApplicationRecord
  has_one_attached :form_2307
  has_many_attached :deposit_slip

  belongs_to :company
  belongs_to :invoice

  validates :company_id, :invoice_id, presence: true
end