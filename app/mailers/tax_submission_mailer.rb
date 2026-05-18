class TaxSubmissionMailer < ApplicationMailer
  def confirmation_email(tax_submission)
    @tax_submission = tax_submission
    @sender_source = sender_source

    mail(
      to: @tax_submission.email,
      subject: "Tax Document Submission Confirmation"
    )
  end

  def notify_superadmins(tax_submission)
    @tax_submission = tax_submission
    mail(
      bcc: User.where(role: "superadmin").pluck(:email),
      subject: "New Tax Submission Received"
    )
  end

  def status_updated(tax_submission, status_message)
    @tax_submission = tax_submission
    @status_message = status_message

    mail(
      to: @tax_submission.email,
      subject: "Your Tax Submission Has Been Updated"
    )
  end

  def notify_invoice_sender(tax_submission)
    @tax_submission = tax_submission
    @invoice = tax_submission.invoice
    invoice_sender = @invoice&.sender_user

    return unless invoice_sender

    mail(
      to: invoice_sender.email,
      subject: "New tax documents submitted for your invoice"
    )
  end

  private

  def sender_source
    submission_email = @tax_submission.email.presence
    return submission_email if submission_email.present?

    configured_sender = Array(self.class.default_params[:from]).first.to_s.presence
    normalized_sender = sanitize_sender(configured_sender)

    normalized_sender.presence || Rails.application.class.module_parent_name || "Tax Form Hub"
  end

  def sanitize_sender(value)
    return nil if value.blank?

    value = value.strip
    value = value.delete_prefix("[").delete_suffix("]") if value == "[EMAIL_ADDRESS]"
    value.presence
  end
end
