class Location < ApplicationRecord
  belongs_to :user

  has_many :ship_from_invoices, class_name: "Invoice", foreign_key: "ship_from_location_id", dependent: :nullify
  has_many :remit_to_invoices, class_name: "Invoice", foreign_key: "remit_to_location_id", dependent: :nullify
  has_many :tax_representative_invoices, class_name: "Invoice", foreign_key: "tax_representative_location_id", dependent: :nullify
end

