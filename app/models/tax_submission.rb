class TaxSubmission < ApplicationRecord
  has_one_attached :form_2307
  has_many_attached :deposit_slip
end