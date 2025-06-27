class Invoice < ApplicationRecord
  has_one_attached :attachment

  validate :attachment_type_allowed

  def new
    @invoice = Invoice.new
    @ship_from_locations = Location.where(location_type: "Ship From")
  end

  private

  def attachment_type_allowed
    return unless attachment.attached?

    acceptable_types = ["application/pdf", "image/jpeg", "image/png"]
    unless acceptable_types.include?(attachment.blob.content_type)
      errors.add(:attachment, "must be a PDF or image file (JPEG, PNG).")
    end
  end
end
