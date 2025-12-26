class TaxSubmission < ApplicationRecord
  has_one_attached :form_2307
  has_many_attached :deposit_slip

  belongs_to :company
  belongs_to :invoice

  validates :company_id, :invoice_id, presence: true

  before_create :set_transaction_id
  after_update :sync_archived_status, if: :saved_change_to_archived?

  private

  def sync_archived_status
    return unless invoice

    invoice.update(archived: archived) if invoice.archived != archived
  end

  def set_transaction_id
    last_id = TaxSubmission.where(email: email).maximum(:user_transaction_id) || 0
    self.user_transaction_id = last_id + 1
  end
end