class Invoice < ApplicationRecord
  has_one_attached :attachment

  validate :attachment_size_within_limit

  private

  def attachment_size_within_limit
    if attachment.attached? && attachment.blob.byte_size > 10.megabytes
      errors.add(:attachment, "is too large. Max size is 10MB.")
    end
  end
end
