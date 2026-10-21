# Server-side validation for `has_one_attached :profile_image` (User avatar, Company logo).
#
# The browser crops/re-encodes avatars to JPEG or PNG before upload, but the client
# can never be trusted, so the stored blob is validated here as well:
#   * Content type comes from Active Storage's Marcel-based identification, which
#     sniffs the file's magic bytes rather than trusting the extension/declared type.
#   * SVG is intentionally excluded (it can carry active content / scripts).
#   * Validation only runs when a new image is being attached, so records with a
#     legacy avatar can still be saved when editing other fields.
#
# TODO(security): Consider malware scanning of uploaded images before storage.
module ProfileImageValidatable
  extend ActiveSupport::Concern

  PROFILE_IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  PROFILE_IMAGE_MAX_BYTES = 5.megabytes

  included do
    validate :validate_profile_image_upload, if: :profile_image_changing?
  end

  private

  def profile_image_changing?
    attachment_changes["profile_image"].present?
  end

  def validate_profile_image_upload
    return unless profile_image.attached?

    blob = profile_image.blob
    return if blob.nil?

    unless PROFILE_IMAGE_CONTENT_TYPES.include?(blob.content_type.to_s)
      errors.add(:profile_image, "must be a JPG, PNG, GIF, or WebP image")
    end

    if blob.byte_size.to_i > PROFILE_IMAGE_MAX_BYTES
      errors.add(:profile_image, "must be smaller than #{PROFILE_IMAGE_MAX_BYTES / 1.megabyte} MB")
    end
  end
end
