# frozen_string_literal: true

require "test_helper"

class UniformEmailsTest < ActionMailer::TestCase
  setup do
    @sender = User.create!(
      email: "sender_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      role: "superadmin"
    )
    @recipient = User.create!(
      email: "recipient_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @sender_company = Company.create!(name: "Meteor Sender Corp", user: @sender)
    @sender.update!(company: @sender_company)

    @recipient_company = Company.create!(name: "Partner Client Inc", user: @recipient)
    @recipient.update!(company: @recipient_company)

    @invoice = Invoice.create!(
      user: @sender,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-2026-#{rand(1000..9999)}",
      recipient_company: @recipient_company,
      currency: "PHP",
      line_items_data: [
        { "description" => "Consulting Services", "quantity" => "1", "price" => "12500.50", "tax" => "0" }
      ]
    )

    @quote = Invoice.create!(
      user: @sender,
      invoice_type: "sale",
      invoice_category: "quote",
      invoice_number: "QTE-2026-#{rand(1000..9999)}",
      recipient_company: @recipient_company,
      currency: "USD",
      line_items_data: [
        { "description" => "Annual Retainer", "quantity" => "1", "price" => "499.00", "tax" => "0" }
      ]
    )

    @credit_note = Invoice.create!(
      user: @sender,
      invoice_type: "sale",
      invoice_category: "credit_note",
      invoice_number: "CN-2026-#{rand(1000..9999)}",
      recipient_company: @recipient_company,
      currency: "PHP",
      line_items_data: [
        { "description" => "Billing Adjustment", "quantity" => "1", "price" => "1500.00", "tax" => "0" }
      ]
    )

    @tax_submission = TaxSubmission.create!(
      email: @recipient.email,
      company: @recipient_company,
      invoice: @invoice,
      details: "Form 2307 Q3 filing"
    )
  end

  def assert_uniform_email_design(mail, expected_category:, expected_text:, expected_plain_text: nil)
    assert_not_nil mail
    assert_not_nil mail.html_part, "Expected HTML part for #{mail.subject}"
    assert_not_nil mail.text_part, "Expected plain-text part for #{mail.subject}"

    html = mail.html_part.decoded
    text = mail.text_part.decoded

    assert_includes html, "email-container"
    assert_includes html, "Tax Form Hub"
    assert_includes html, "TFH"
    assert_includes html, expected_category
    assert_includes html, "All rights reserved."
    assert_includes html, expected_text

    assert_includes text, "TAX FORM HUB"
    assert_includes text.downcase, (expected_plain_text || expected_text).downcase
    refute_includes text, "&#39;", "Plain-text part should not contain HTML entities"
  end

  test "Devise::Mailer inherits from ApplicationMailer and renders uniform designed emails" do
    assert_operator Devise::Mailer, :<, ApplicationMailer
    assert_equal 1.hour, Devise.reset_password_within

    reset_mail = Devise::Mailer.reset_password_instructions(@recipient, "sample-reset-token")
    assert_uniform_email_design(
      reset_mail,
      expected_category: "Account Security",
      expected_text: "Reset Password",
      expected_plain_text: "reset your password"
    )
    assert_includes reset_mail.html_part.decoded, "sample-reset-token"
    assert_includes reset_mail.html_part.decoded, "1 hour"
    assert_includes reset_mail.html_part.decoded, "Link Valid For"
    assert_includes reset_mail.html_part.decoded, "Expires At"
    assert_includes reset_mail.text_part.decoded, "sample-reset-token"
    assert_includes reset_mail.text_part.decoded, "Link Valid For: 1 hour"
    assert_includes reset_mail.text_part.decoded, "Expires At:"

    email_changed_mail = Devise::Mailer.email_changed(@recipient)
    assert_uniform_email_design(email_changed_mail, expected_category: "Account Security", expected_text: @recipient.email)

    password_change_mail = Devise::Mailer.password_change(@recipient)
    assert_uniform_email_design(password_change_mail, expected_category: "Account Security", expected_text: @recipient.email)
  end

  test "all InvoiceMailer emails share the uniform design and multipart structure" do
    assert_uniform_email_design(
      InvoiceMailer.invoice_sent(@invoice, @recipient),
      expected_category: "Invoice",
      expected_text: @invoice.invoice_number
    )
    assert_uniform_email_design(
      InvoiceMailer.quote_sent(@quote, @recipient),
      expected_category: "Quotation",
      expected_text: @quote.invoice_number
    )
    assert_uniform_email_design(
      InvoiceMailer.invoice_approved(@invoice, @sender, @recipient),
      expected_category: "Invoice",
      expected_text: "Invoice Approved"
    )
    assert_uniform_email_design(
      InvoiceMailer.invoice_rejected(@invoice, @sender, @recipient),
      expected_category: "Invoice",
      expected_text: "Invoice Rejected"
    )
    assert_uniform_email_design(
      InvoiceMailer.quote_approved(@quote, @sender, @recipient),
      expected_category: "Quotation",
      expected_text: "Quotation Approved"
    )
    assert_uniform_email_design(
      InvoiceMailer.quote_rejected(@quote, @sender, @recipient),
      expected_category: "Quotation",
      expected_text: "Quotation Rejected"
    )
    assert_uniform_email_design(
      InvoiceMailer.credit_note_created(@credit_note, @invoice),
      expected_category: "Credit Note",
      expected_text: @credit_note.invoice_number
    )
    assert_uniform_email_design(
      InvoiceMailer.recurring_invoice_failed(@invoice, "Timeout communicating with billing worker"),
      expected_category: "Billing Alert",
      expected_text: "Timeout communicating with billing worker"
    )
  end

  test "all TaxSubmissionMailer emails share the uniform design and multipart structure" do
    assert_uniform_email_design(
      TaxSubmissionMailer.confirmation_email(@tax_submission),
      expected_category: "Tax Submission",
      expected_text: "Form 2307 Q3 filing"
    )
    assert_uniform_email_design(
      TaxSubmissionMailer.notify_invoice_sender(@tax_submission),
      expected_category: "Tax Submission",
      expected_text: @invoice.invoice_number
    )
    assert_uniform_email_design(
      TaxSubmissionMailer.notify_superadmins(@tax_submission),
      expected_category: "Admin Alert",
      expected_text: @recipient.email
    )
    assert_uniform_email_design(
      TaxSubmissionMailer.status_updated(@tax_submission, "Reviewed and approved"),
      expected_category: "Tax Submission",
      expected_text: "Reviewed and approved"
    )
  end

  test "NetworkInvitationMailer renders uniform design and escapes untrusted user input" do
    xss_payload = '<script>alert("xss")</script>Hello & welcome'
    mail = NetworkInvitationMailer.invite_company(
      inviter: @sender,
      company_name: "<b>Untrusted Co</b>",
      recipient_email: "prospect@example.com",
      invite_token: "secure-token-123",
      message: xss_payload,
      signup_url: "https://example.com/users/sign_up?invite_token=secure-token-123"
    )

    assert_uniform_email_design(
      mail,
      expected_category: "Network Invitation",
      expected_text: "Create Account",
      expected_plain_text: "create your account"
    )

    html = mail.html_part.decoded
    text = mail.text_part.decoded
    assert_includes html, "7 days"
    assert_includes html, "Invitation Valid For"
    assert_includes html, "Expires At"
    assert_includes text, "Invitation Valid For: 7 days"
    assert_includes text, "Expires At:"
    refute_includes html, "<script>alert"
    assert_includes html, "&lt;script&gt;alert"
    refute_includes html, "<b>Untrusted Co</b>"
    assert_includes html, "&lt;b&gt;Untrusted Co&lt;/b&gt;"
  end

  test "error messages and tax submission notes are safely HTML-escaped in emails" do
    xss_error = '<img src=x onerror=alert(1)>'
    mail = InvoiceMailer.recurring_invoice_failed(@invoice, xss_error)
    html = mail.html_part.decoded

    refute_includes html, "<img src=x"
    assert_includes html, "&lt;img src=x onerror=alert(1)&gt;"
  end
end
