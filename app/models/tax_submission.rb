class TaxSubmission < ApplicationRecord
  has_one_attached :form_2307
  has_one_attached :deposit_slip
end