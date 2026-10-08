# frozen_string_literal: true

class ActivityLogger
  class << self
    def log(trackable:, actor: nil, action:, description: nil, metadata: {}, company: nil, created_at: nil)
      return unless trackable

      actor_name = if actor.respond_to?(:display_name)
                     actor.display_name
                   elsif actor.is_a?(String)
                     actor
                   elsif trackable.respond_to?(:email) && trackable.email.present?
                     trackable.email.split("@").first.tr("._-", " ").titleize
                   else
                     "User"
                   end

      actor_email = actor.respond_to?(:email) ? actor.email : (trackable.respond_to?(:email) ? trackable.email : nil)
      user_record = actor.is_a?(User) ? actor : nil

      company_record, resolved_company_name = resolve_company_details(actor, trackable, company)

      date_str = (created_at || Time.current).strftime("%b %-d")
      default_desc = "#{actor_name} performed #{action.to_s.humanize.downcase} on #{date_str}"

      meta = (metadata || {}).dup
      meta["company_name"] = resolved_company_name if resolved_company_name.present? && !meta.key?("company_name")

      Activity.create!(
        trackable: trackable,
        user: user_record,
        user_name: actor_name,
        user_email: actor_email,
        company: company_record,
        company_name: resolved_company_name,
        action: action.to_s,
        description: description.presence || default_desc,
        metadata: meta,
        created_at: created_at || Time.current
      )
    rescue StandardError => e
      Rails.logger.error "[ActivityLogger] Failed to log activity: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}"
      nil
    end

    # --- Invoice Activities ---

    def log_invoice_created(invoice, actor)
      return unless invoice

      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      category_name = invoice.standard? ? "Invoice" : invoice.invoice_category.humanize
      desc = "#{actor_name} created #{category_name} ##{invoice.invoice_number} on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "invoice_created",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number,
          invoice_type: invoice.invoice_type,
          invoice_category: invoice.invoice_category,
          total: invoice.grand_total,
          currency: invoice.currency
        }
      )
    end

    def log_invoice_paid(invoice, actor)
      return unless invoice

      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      desc = "#{actor_name} marked Invoice as Paid on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "marked_as_paid",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number,
          status: "paid",
          previous_status: invoice.saved_changes.key?("status") ? invoice.saved_changes["status"].first : "sent"
        }
      )
    end

    def log_invoice_amount_updated(invoice, actor, old_amount, new_amount)
      return unless invoice

      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      sym = invoice.currency.present? ? User.currency_symbol(invoice.currency) : "₱"
      old_str = "#{sym}#{sprintf('%.2f', old_amount.to_f)}"
      new_str = "#{sym}#{sprintf('%.2f', new_amount.to_f)}"
      desc = "#{actor_name} updated the invoice amount on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "amount_updated",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number,
          old_amount: old_amount.to_f,
          new_amount: new_amount.to_f,
          old_amount_formatted: old_str,
          new_amount_formatted: new_str,
          currency: invoice.currency
        }
      )
    end

    def log_invoice_status_changed(invoice, actor, old_status, new_status)
      return unless invoice
      return if old_status.to_s.downcase == new_status.to_s.downcase

      if new_status.to_s.downcase == "paid"
        log_invoice_paid(invoice, actor)
        return
      end

      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      desc = "#{actor_name} marked Invoice as #{new_status.to_s.titleize} on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "status_changed",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number,
          old_status: old_status,
          new_status: new_status
        }
      )
    end

    def log_invoice_sent(invoice, actor)
      return unless invoice

      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      recipient_name = invoice.recipient_company&.name || "Customer"
      category_name = invoice.standard? ? "Invoice" : invoice.invoice_category.humanize
      desc = "#{actor_name} sent #{category_name} to #{recipient_name} on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "invoice_sent",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number,
          recipient: recipient_name
        }
      )
    end

    def log_invoice_updated(invoice, actor, previous_grand_total: nil, previous_status: nil)
      return unless invoice

      # Check if status changed
      if previous_status.present? && previous_status.to_s != invoice.status.to_s
        log_invoice_status_changed(invoice, actor, previous_status, invoice.status)
        return
      end

      # Check if amount changed
      if previous_grand_total.present? && (previous_grand_total.to_f - invoice.grand_total.to_f).abs > 0.001
        log_invoice_amount_updated(invoice, actor, previous_grand_total, invoice.grand_total)
        return
      end

      # Generic invoice update
      actor_name = resolve_name(actor, invoice)
      date_str = Time.current.strftime("%b %-d")
      category_name = invoice.standard? ? "Invoice" : invoice.invoice_category.humanize
      desc = "#{actor_name} updated #{category_name} ##{invoice.invoice_number} on #{date_str}"

      log(
        trackable: invoice,
        actor: actor,
        action: "invoice_updated",
        description: desc,
        metadata: {
          invoice_number: invoice.invoice_number
        }
      )
    end

    # --- Tax Submission Activities ---

    def log_tax_submitted(tax_submission, actor)
      return unless tax_submission

      actor_name = resolve_name(actor, tax_submission)
      date_str = Time.current.strftime("%b %-d")

      form_name = if tax_submission.form_2307.attached? && tax_submission.deposit_slip.attached?
                    "Form 2307 and Deposit Slip"
                  elsif tax_submission.deposit_slip.attached? && !tax_submission.form_2307.attached?
                    "Deposit Slip"
                  else
                    "Form 2307"
                  end

      desc = "#{actor_name} submitted #{form_name} on #{date_str}"

      comp_record, comp_name = resolve_company_details(actor, tax_submission)

      meta = {
        transaction_id: tax_submission.company_submission_id || tax_submission.user_transaction_id || tax_submission.id,
        invoice_number: tax_submission.invoice&.invoice_number,
        company_name: comp_name,
        form_2307_attached: tax_submission.form_2307.attached?,
        deposit_slip_attached: tax_submission.deposit_slip.attached?,
        deposit_slip_count: tax_submission.deposit_slip.attached? ? tax_submission.deposit_slip.count : 0
      }

      # 1. Log on the tax submission
      log(
        trackable: tax_submission,
        actor: actor,
        action: "tax_submitted",
        description: desc,
        company: comp_record || comp_name,
        metadata: meta
      )

      # 2. Also log on the associated invoice for timeline visibility on invoice history!
      if tax_submission.invoice.present?
        log(
          trackable: tax_submission.invoice,
          actor: actor,
          action: "tax_submitted",
          description: "#{actor_name} submitted #{form_name} on #{date_str}",
          company: comp_record || comp_name,
          metadata: meta.merge(tax_submission_id: tax_submission.id)
        )
      end
    end

    def log_tax_status_updated(tax_submission, actor, field_name, new_value)
      return unless tax_submission

      actor_name = resolve_name(actor, tax_submission)
      date_str = Time.current.strftime("%b %-d")

      action_key = case field_name.to_s
                   when "reviewed"
                     new_value ? "reviewed" : "unreviewed"
                   when "processed"
                     new_value ? "processed" : "unprocessed"
                   when "archived"
                     new_value ? "archived" : "unarchived"
                   else
                     "updated"
                   end

      desc = case action_key
             when "reviewed"
               "#{actor_name} marked submission as Reviewed on #{date_str}"
             when "unreviewed"
               "#{actor_name} unmarked submission as Reviewed on #{date_str}"
             when "processed"
               "#{actor_name} marked submission as Processed on #{date_str}"
             when "unprocessed"
               "#{actor_name} unmarked submission as Processed on #{date_str}"
             when "archived"
               "#{actor_name} archived submission on #{date_str}"
             when "unarchived"
               "#{actor_name} unarchived submission on #{date_str}"
             else
               "#{actor_name} updated submission on #{date_str}"
             end

      log(
        trackable: tax_submission,
        actor: actor,
        action: action_key,
        description: desc,
        metadata: {
          field: field_name,
          new_value: new_value,
          invoice_number: tax_submission.invoice&.invoice_number
        }
      )
    end

    def log_archived(record, actor)
      return unless record

      actor_name = resolve_name(actor, record)
      date_str = Time.current.strftime("%b %-d")
      model_name = record.class.model_name.human
      desc = "#{actor_name} archived #{model_name} on #{date_str}"

      log(
        trackable: record,
        actor: actor,
        action: "archived",
        description: desc,
        metadata: {}
      )
    end

    def log_unarchived(record, actor)
      return unless record

      actor_name = resolve_name(actor, record)
      date_str = Time.current.strftime("%b %-d")
      model_name = record.class.model_name.human
      desc = "#{actor_name} unarchived #{model_name} on #{date_str}"

      log(
        trackable: record,
        actor: actor,
        action: "unarchived",
        description: desc,
        metadata: {}
      )
    end

    private

    def resolve_name(actor, record)
      if actor.respond_to?(:display_name)
        actor.display_name
      elsif actor.is_a?(String)
        actor
      elsif record.respond_to?(:email) && record.email.present?
        record.email.split("@").first.tr("._-", " ").titleize
      elsif record.respond_to?(:user) && record.user.present?
        record.user.display_name
      else
        "User"
      end
    end

    def resolve_company_details(actor, trackable, explicit_company = nil)
      comp_record = nil
      comp_name = nil

      if explicit_company.is_a?(Company)
        comp_record = explicit_company
        comp_name = explicit_company.name
      elsif explicit_company.is_a?(String) && explicit_company.present?
        comp_name = explicit_company
        comp_record = Company.find_by(name: explicit_company)
      end

      if comp_name.blank? && actor.is_a?(User)
        comp_record = actor.company || actor.companies.first
        comp_name = comp_record&.name
      end

      if comp_name.blank? && trackable.present?
        case trackable
        when Invoice
          if actor.is_a?(User) && actor.id == trackable.user_id
            comp_record = trackable.sale_from || trackable.user&.company || trackable.user&.companies&.first
            comp_name = comp_record&.name
          else
            comp_record = trackable.recipient_company || trackable.sale_from
            comp_name = comp_record&.name
          end
        when TaxSubmission
          comp_record = trackable.company || trackable.invoice&.recipient_company || trackable.invoice&.sale_from
          comp_name = comp_record&.name || trackable.try(:company_name)
        end
      end

      [comp_record, comp_name]
    end
  end
end
