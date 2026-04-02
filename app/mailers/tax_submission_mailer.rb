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

  def status_updated(tax_submission, status_message)
    @tax_submission = tax_submission
    @status_message = status_message

    mail(
      to: @tax_submission.email,
      subject: "Your Tax Submission Has Been Updated"
    )
  end

  def notify_company(tax_submission)
    @tax_submission = tax_submission
    company_user = @tax_submission.company&.user
    if company_user
      mail(
        to: company_user.email,
        subject: "New tax documents submitted for your company"
      )
    end
  end
end
