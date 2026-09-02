class NotificationService
  class << self
    def notify(recipient:, actor: nil, notifiable: nil, category: "invoices", action:, title:, message: nil, target_url: nil)
      return unless recipient

      # Avoid notifying oneself unless explicit system action
      return if actor && actor.id == recipient.id

      Notification.create!(
        recipient: recipient,
        actor: actor,
        notifiable: notifiable,
        category: category,
        action: action,
        title: title,
        message: message,
        target_url: target_url
      )
    rescue StandardError => e
      Rails.logger.error "[NotificationService] Failed to create notification: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
      nil
    end

    def resolve_invoice_for_recipient(invoice, recipient_user)
      return invoice if invoice.blank? || recipient_user.blank?
      return invoice if invoice.user_id == recipient_user.id

      # If invoice does not belong to recipient_user, look up recipient_user's counterpart version
      target_type = (invoice.invoice_type == "sale" ? "purchase" : "sale")
      recipient_user.invoices.find_by(
        invoice_number: invoice.invoice_number,
        invoice_type: target_type
      ) || recipient_user.invoices.find_by(invoice_number: invoice.invoice_number) || invoice
    end

    def notify_tax_submitted(tax_submission, actor = nil)
      invoice = tax_submission.invoice
      return unless invoice

      # 1. Notify the invoice sender/seller
      recipient_user = invoice.sender_user || invoice.user
      sender_name = actor&.company&.name || actor&.email || tax_submission.email || "A customer"

      if recipient_user
        notify(
          recipient: recipient_user,
          actor: actor,
          notifiable: tax_submission,
          category: :taxes,
          action: "tax_submitted",
          title: "BIR Form 2307 Submitted",
          message: "#{sender_name} submitted tax documents for Invoice ##{invoice.invoice_number}.",
          target_url: "/tax_submissions"
        )
      end

      # 2. Notify all Superadmins
      superadmins = User.where(role: "superadmin")
      superadmins = superadmins.where.not(id: actor.id) if actor

      superadmins.find_each do |admin|
        notify(
          recipient: admin,
          actor: actor,
          notifiable: tax_submission,
          category: :taxes,
          action: "tax_submitted_admin",
          title: "New Tax Submission",
          message: "Tax documents submitted for Invoice ##{invoice.invoice_number} by #{sender_name}.",
          target_url: "/admin/tax_submissions"
        )
      end
    end

    def notify_tax_status_updated(tax_submission, status_message, actor = nil)
      submitter = User.find_by(email: tax_submission.email)
      return unless submitter

      invoice_num = tax_submission.invoice&.invoice_number || "tax filing"
      title = if tax_submission.reviewed? && tax_submission.processed?
                "Tax Submission Approved & Processed"
              elsif tax_submission.reviewed?
                "Tax Submission Reviewed"
              elsif tax_submission.processed?
                "Tax Submission Processed"
              else
                "Tax Submission Updated"
              end

      notify(
        recipient: submitter,
        actor: actor,
        notifiable: tax_submission,
        category: :taxes,
        action: "tax_status_updated",
        title: title,
        message: status_message.presence || "Your tax submission for Invoice ##{invoice_num} has been updated.",
        target_url: "/tax_submissions/home"
      )
    end

    def notify_invoice_sent(invoice, recipient_user, actor = nil)
      return unless recipient_user

      target_invoice = resolve_invoice_for_recipient(invoice, recipient_user)
      sender_name = actor&.company&.name || actor&.email || "A partner"
      category_name = invoice.quote? ? "Quotation" : (invoice.credit_note? ? "Credit Note" : "Invoice")

      action_name = if invoice.credit_note?
                      "credit_note_created"
                    elsif invoice.quote?
                      "quote_sent"
                    else
                      "invoice_sent"
                    end

      notify(
        recipient: recipient_user,
        actor: actor || invoice.user,
        notifiable: target_invoice,
        category: :invoices,
        action: action_name,
        title: "New #{category_name} Received",
        message: "#{sender_name} sent you #{category_name} ##{invoice.invoice_number}.",
        target_url: "/invoices/#{target_invoice.id}"
      )
    end

    def notify_invoice_approved(invoice, sender_user, actor = nil)
      return unless sender_user

      target_invoice = resolve_invoice_for_recipient(invoice, sender_user)
      actor_name = actor&.company&.name || actor&.email || "The recipient"
      category_name = invoice.quote? ? "Quotation" : "Invoice"

      notify(
        recipient: sender_user,
        actor: actor,
        notifiable: target_invoice,
        category: :invoices,
        action: invoice.quote? ? "quote_approved" : "invoice_approved",
        title: "#{category_name} Approved",
        message: "#{category_name} ##{invoice.invoice_number} was approved by #{actor_name}.",
        target_url: "/invoices/#{target_invoice.id}"
      )
    end

    def notify_invoice_rejected(invoice, sender_user, actor = nil)
      return unless sender_user

      target_invoice = resolve_invoice_for_recipient(invoice, sender_user)
      actor_name = actor&.company&.name || actor&.email || "The recipient"
      category_name = invoice.quote? ? "Quotation" : "Invoice"

      notify(
        recipient: sender_user,
        actor: actor,
        notifiable: target_invoice,
        category: :invoices,
        action: invoice.quote? ? "quote_rejected" : "invoice_rejected",
        title: "#{category_name} Rejected",
        message: "#{category_name} ##{invoice.invoice_number} was rejected by #{actor_name}.",
        target_url: "/invoices/#{target_invoice.id}"
      )
    end

    def notify_invoice_paid(invoice, counterparty_user, actor = nil)
      return unless counterparty_user

      target_invoice = resolve_invoice_for_recipient(invoice, counterparty_user)

      notify(
        recipient: counterparty_user,
        actor: actor,
        notifiable: target_invoice,
        category: :invoices,
        action: "invoice_paid",
        title: "Invoice Marked as Paid",
        message: "Invoice ##{invoice.invoice_number} was marked as paid.",
        target_url: "/invoices/#{target_invoice.id}"
      )
    end

    def notify_credit_note_created(credit_note, original_invoice, recipient_user, actor = nil)
      return unless recipient_user

      target_credit_note = resolve_invoice_for_recipient(credit_note, recipient_user)
      sender_name = actor&.company&.name || actor&.email || "A partner"
      orig_num = original_invoice&.invoice_number || "original invoice"

      notify(
        recipient: recipient_user,
        actor: actor || credit_note.user,
        notifiable: target_credit_note,
        category: :invoices,
        action: "credit_note_created",
        title: "Credit Note Issued",
        message: "#{sender_name} issued Credit Note ##{credit_note.invoice_number} for Invoice ##{orig_num}.",
        target_url: "/invoices/#{target_credit_note.id}"
      )
    end
  end
end
