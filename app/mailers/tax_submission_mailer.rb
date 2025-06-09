class TaxSubmissionMailer < ApplicationMailer
  def confirmation_email(tax_submission)
    @tax_submission = tax_submission
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
end
