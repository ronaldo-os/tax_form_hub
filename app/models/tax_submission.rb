class TaxSubmission < ApplicationRecord
  has_one_attached :form_2307
  has_many_attached :deposit_slip

  belongs_to :company
  belongs_to :invoice

  validates :company_id, :invoice_id, presence: true
  validate :reject_heic_files

  before_create :set_transaction_id
  after_update :sync_archived_status, if: :saved_change_to_archived?

  private

  def sync_archived_status
    return unless invoice

    invoice.update(archived: archived) if invoice.archived != archived
  end

  def set_transaction_id
    # Generate user_transaction_id scoped to email (per-user sequence for Submit Documents)
    last_user_id = TaxSubmission.where(email: email).maximum(:user_transaction_id) || 0
    self.user_transaction_id = last_user_id + 1

    # Generate company_submission_id scoped to company_id (per-company sequence for Incoming Submissions)
    if company_id.present?
      last_company_id = TaxSubmission.where(company_id: company_id).maximum(:company_submission_id) || 0
      self.company_submission_id = last_company_id + 1
    end
  end

  def reject_heic_files
    heic_types = %w[image/heic image/heif .heic .heif]

    if form_2307.attached? && heic_types.any? { |type| form_2307.content_type&.downcase&.include?(type) || form_2307.filename.to_s.downcase.end_with?(type) }
      errors.add(:form_2307, "HEIC files are not supported. Please convert to JPG, PNG, or PDF.")
      form_2307.purge
    end

    deposit_slip.attachments.each do |file|
      if heic_types.any? { |type| file.content_type&.downcase&.include?(type) || file.filename.to_s.downcase.end_with?(type) }
        errors.add(:deposit_slip, "HEIC files are not supported. Please convert to JPG, PNG, or PDF.")
        file.purge
      end
    end
  end
end