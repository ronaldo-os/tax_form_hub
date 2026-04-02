class InvoiceMailer < ApplicationMailer
  default from: "from@example.com"

  ACTION_SUBJECTS = {
    invoice_sent: "You’ve received a new invoice",
    quote_sent: "You’ve received a new quotation",
    invoice_approved: "Your invoice has been approved",
    invoice_rejected: "Your invoice has been rejected",
    quote_approved: "Your quotation has been approved",
    quote_rejected: "Your quotation has been rejected"
  }.freeze

  def transaction_notification(invoice, recipient_user, action)
    @invoice = invoice
    @recipient_user = recipient_user
    @action = action
    @sender_user = invoice.user

    mail(
      to: recipient_user.email,
      subject: ACTION_SUBJECTS[action],
      template_name: "transaction_notification"
    )
  end

  def invoice_sent(invoice, recipient_user)
    transaction_notification(invoice, recipient_user, :invoice_sent)
  end

  def quote_sent(invoice, recipient_user)
    transaction_notification(invoice, recipient_user, :quote_sent)
  end

  def invoice_approved(invoice, sender_user)
    transaction_notification(invoice, sender_user, :invoice_approved)
  end

  def invoice_rejected(invoice, sender_user)
    transaction_notification(invoice, sender_user, :invoice_rejected)
  end

  def quote_approved(invoice, sender_user)
    transaction_notification(invoice, sender_user, :quote_approved)
  end

  def quote_rejected(invoice, sender_user)
    transaction_notification(invoice, sender_user, :quote_rejected)
  end

  def credit_note_created(credit_note, original_invoice)
    @credit_note = credit_note
    @original_invoice = original_invoice

    recipients = []
    recipients << credit_note.user.email if credit_note.user
    recipients << credit_note.recipient_company.user.email if credit_note.recipient_company&.user
    recipients.uniq!

    mail(
      to: recipients,
      subject: "A credit note has been created"
    )
  end
end
