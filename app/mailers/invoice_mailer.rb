class InvoiceMailer < ApplicationMailer
  default from: "from@example.com"

  def invoice_sent(invoice, recipient_user)
    @invoice = invoice
    @recipient_user = recipient_user
    mail(
      to: recipient_user.email,
      subject: "You’ve received a new invoice"
    )
  end
end