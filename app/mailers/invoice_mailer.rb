class InvoiceMailer < ApplicationMailer
  default from: "taxformhub@meteorsoftwareph.com"

  ACTION_SUBJECTS = {
    invoice_sent: "You’ve received a new invoice",
    quote_sent: "You’ve received a new quotation",
    invoice_approved: "Your invoice has been approved",
    invoice_rejected: "Your invoice has been rejected",
    quote_approved: "Your quotation has been approved",
    quote_rejected: "Your quotation has been rejected"
  }.freeze

  def transaction_notification(invoice, recipient_user, action, action_performer = nil)
    return unless recipient_user

    @invoice = invoice
    @recipient_user = recipient_user
    @action = action
    @sender_user = action_performer || invoice.user
    # For purchase invoices, the original sender is associated with sale_from company
    # For sale invoices, the original sender is invoice.user
    @original_sender_user = invoice.invoice_type == "purchase" && invoice.sale_from ? invoice.sale_from.user : invoice.user

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

  # For approval/rejection, the action_performer is the recipient approving/rejecting
  def invoice_approved(invoice, sender_user, action_performer_user = nil)
    transaction_notification(invoice, sender_user, :invoice_approved, action_performer_user || invoice.user)
  end

  def invoice_rejected(invoice, sender_user, action_performer_user = nil)
    transaction_notification(invoice, sender_user, :invoice_rejected, action_performer_user || invoice.user)
  end

  def quote_approved(invoice, sender_user, action_performer_user = nil)
    transaction_notification(invoice, sender_user, :quote_approved, action_performer_user || invoice.user)
  end

  def quote_rejected(invoice, sender_user, action_performer_user = nil)
    transaction_notification(invoice, sender_user, :quote_rejected, action_performer_user || invoice.user)
  end

  def credit_note_created(credit_note, original_invoice)
    @credit_note = credit_note
    @original_invoice = original_invoice

    # Send credit note notification to the invoice receiver (recipient of the original invoice)
    recipient_user = original_invoice.recipient_company&.user
    
    if recipient_user
      mail(
        to: recipient_user.email,
        subject: "A credit note has been created"
      )
    end
  end
end
