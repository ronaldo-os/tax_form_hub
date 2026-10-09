# frozen_string_literal: true

class ActivitiesController < ApplicationController
  before_action :authenticate_user!

  ALLOWED_TRACKABLE_TYPES = %w[Invoice TaxSubmission].freeze

  def index
    trackable_type = params[:trackable_type].to_s.camelize
    trackable_id = params[:trackable_id].to_i

    unless ALLOWED_TRACKABLE_TYPES.include?(trackable_type) && trackable_id.positive?
      return render json: { success: false, error: "Invalid trackable resource." }, status: :bad_request
    end

    trackable = find_and_authorize_trackable(trackable_type, trackable_id)
    return if performed?

    db_activities = trackable.activities.recent.includes(:user, :company).to_a
    activities = ensure_baseline_activities(trackable, db_activities)

    resource_title = case trackable
                     when Invoice
                       trackable.standard? ? "Invoice ##{trackable.invoice_number}" : "#{trackable.invoice_category.humanize} ##{trackable.invoice_number}"
                     when TaxSubmission
                       tx_id = trackable.company_submission_id || trackable.user_transaction_id || trackable.id
                       "Tax Submission ##{tx_id}"
                     end

    resource_number = case trackable
                      when Invoice then trackable.invoice_number
                      when TaxSubmission then (trackable.company_submission_id || trackable.user_transaction_id || trackable.id).to_s
                      end

    serialized = activities.map do |activity|
      serialize_activity(activity)
    end

    payment_summary = trackable.is_a?(Invoice) ? serialize_payment_summary(trackable) : nil

    render json: {
      success: true,
      trackable_type: trackable_type,
      trackable_id: trackable.id,
      resource_title: resource_title,
      resource_number: resource_number,
      payment_summary: payment_summary,
      activities_count: serialized.size,
      activities: serialized
    }
  end

  private

  def find_and_authorize_trackable(type, id)
    case type
    when "Invoice"
      invoice = Invoice.includes(:recipient_company, :sale_from, :user).find_by(id: id)
      unless invoice
        render json: { success: false, error: "Invoice not found." }, status: :not_found
        return nil
      end

      unless authorized_for_invoice?(invoice)
        render json: { success: false, error: "You are not authorized to view this invoice's history." }, status: :forbidden
        return nil
      end

      invoice
    when "TaxSubmission"
      submission = TaxSubmission.includes(:company, invoice: [:recipient_company, :sale_from, :user]).find_by(id: id)
      unless submission
        render json: { success: false, error: "Tax submission not found." }, status: :not_found
        return nil
      end

      unless authorized_for_tax_submission?(submission)
        render json: { success: false, error: "You are not authorized to view this submission's history." }, status: :forbidden
        return nil
      end

      submission
    end
  end

  def authorized_for_invoice?(invoice)
    return true if current_user.superadmin?
    return true if invoice.user_id == current_user.id

    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq
    return true if my_company_ids.include?(invoice.recipient_company_id)
    return true if my_company_ids.include?(invoice.sale_from_id)

    false
  end

  def authorized_for_tax_submission?(submission)
    return true if current_user.superadmin?
    return true if submission.email.to_s.downcase == current_user.email.to_s.downcase

    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq
    return true if my_company_ids.include?(submission.company_id)

    if submission.invoice.present?
      return authorized_for_invoice?(submission.invoice)
    end

    false
  end

  def serialize_activity(activity)
    icon_cfg = activity.icon_config
    {
      id: activity.id,
      action: activity.action,
      actor_name: activity.actor_name,
      actor_initial: activity.actor_initial,
      user_name: activity.user_name.presence || activity.actor_name,
      user_email: activity.user_email,
      company_name: activity.actor_company_name,
      description: activity.description,
      formatted_date: activity.formatted_date_with_year,
      formatted_time: activity.formatted_time,
      time_ago: activity.time_ago,
      created_at: activity.created_at.iso8601,
      icon: icon_cfg[:icon],
      color_class: icon_cfg[:color_class],
      badge_class: icon_cfg[:badge_class],
      badge_label: icon_cfg[:label],
      metadata: activity.metadata || {}
    }
  end

  def serialize_payment_summary(invoice)
    return nil if invoice.quote?

    grand_total = invoice.grand_total.to_f
    total_paid = invoice.total_paid.to_f
    remaining_balance = invoice.remaining_balance.to_f
    pct_paid = grand_total.positive? ? [((total_paid / grand_total) * 100).round, 100].min : 0
    can_record = invoice.invoice_type == "sale" &&
                 %w[sent approved partially_paid].include?(invoice.status) &&
                 !invoice.has_associated_credit_note? &&
                 authorized_for_invoice?(invoice)

    {
      invoice_id: invoice.id,
      invoice_number: invoice.invoice_number,
      currency_symbol: invoice.currency_symbol,
      grand_total: grand_total,
      formatted_grand_total: "#{invoice.currency_symbol} #{ActionController::Base.helpers.number_with_precision(grand_total, precision: 2, delimiter: ',')}",
      total_paid: total_paid,
      formatted_total_paid: "#{invoice.currency_symbol} #{ActionController::Base.helpers.number_with_precision(total_paid, precision: 2, delimiter: ',')}",
      remaining_balance: remaining_balance,
      formatted_remaining_balance: "#{invoice.currency_symbol} #{ActionController::Base.helpers.number_with_precision(remaining_balance, precision: 2, delimiter: ',')}",
      percent_paid: pct_paid,
      status: invoice.status,
      status_title: invoice.status.to_s.titleize,
      status_badge_class: invoice.payment_status_badge_class,
      can_record_payment: can_record,
      payments_count: invoice.payments.count,
      payments: invoice.payments.recent.map do |p|
        {
          id: p.id,
          payment_date: p.payment_date.strftime("%b %d, %Y"),
          payment_method: p.payment_method,
          payment_method_icon: p.payment_method_icon,
          payment_method_badge_class: p.payment_method_badge_class,
          reference_number: p.reference_number,
          amount: p.amount.to_f,
          formatted_amount: p.formatted_amount,
          notes: p.notes.to_s,
          user_email: p.user&.email || "System",
          can_delete: invoice.invoice_type == "sale" && !invoice.has_associated_credit_note? && authorized_for_invoice?(invoice),
          delete_path: Rails.application.routes.url_helpers.invoice_payment_path(invoice, p)
        }
      end
    }
  end

  def ensure_baseline_activities(trackable, db_activities)
    synthesized = []

    case trackable
    when Invoice
      creator = trackable.user
      creator_name = creator&.display_name || "User"
      date_str = trackable.created_at.strftime("%b %-d")
      category_name = trackable.standard? ? "Invoice" : trackable.invoice_category.humanize
      creator_company = trackable.sale_from || creator&.company || creator&.companies&.first
      creator_company_name = creator_company&.name

      recipient_company = trackable.recipient_company
      recipient_company_name = recipient_company&.name
      recipient_user = recipient_company&.user

      # 1. Invoice Created milestone
      unless db_activities.any? { |a| a.action == "invoice_created" }
        synthesized << Activity.new(
          trackable: trackable,
          user: creator,
          user_name: creator_name,
          user_email: creator&.email,
          company: creator_company,
          company_name: creator_company_name,
          action: "invoice_created",
          description: "#{creator_name} created #{category_name} ##{trackable.invoice_number} on #{date_str}",
          metadata: {
            invoice_number: trackable.invoice_number,
            invoice_type: trackable.invoice_type,
            invoice_category: trackable.invoice_category,
            company_name: creator_company_name,
            total: trackable.grand_total,
            currency: trackable.currency
          },
          created_at: trackable.created_at
        )
      end

      # 2. Invoice Sent milestone (if invoice status has progressed past draft)
      if trackable.status != "draft" && db_activities.none? { |a| %w[invoice_sent quote_sent].include?(a.action) }
        sent_time = [trackable.created_at + 1.second, trackable.updated_at].min
        sent_date_str = sent_time.strftime("%b %-d")
        recipient_display = recipient_company_name.presence || "Customer"
        action_name = trackable.quote? ? "quote_sent" : "invoice_sent"

        synthesized << Activity.new(
          trackable: trackable,
          user: creator,
          user_name: creator_name,
          user_email: creator&.email,
          company: creator_company,
          company_name: creator_company_name,
          action: action_name,
          description: "#{creator_name} sent #{category_name} to #{recipient_display} on #{sent_date_str}",
          metadata: {
            invoice_number: trackable.invoice_number,
            recipient: recipient_display,
            company_name: creator_company_name
          },
          created_at: sent_time
        )
      end

      # 3. Status Milestones (Approved / Rejected)
      if trackable.status == "approved"
        has_approved = db_activities.any? do |a|
          a.action == "approved" ||
            (a.action == "status_changed" && (a.metadata&.dig("new_status") == "approved" || a.description.to_s.downcase.include?("approved")))
        end

        unless has_approved
          approver = (trackable.invoice_type == "purchase") ? creator : recipient_user
          approver_name = approver&.display_name || recipient_company_name.presence || "Customer"
          app_company = (trackable.invoice_type == "purchase") ? creator_company : (recipient_company || creator_company)
          app_date_str = trackable.updated_at.strftime("%b %-d")

          synthesized << Activity.new(
            trackable: trackable,
            user: approver,
            user_name: approver_name,
            user_email: approver&.email,
            company: app_company,
            company_name: app_company&.name,
            action: "approved",
            description: "#{approver_name} marked Invoice as Approved on #{app_date_str}",
            metadata: {
              invoice_number: trackable.invoice_number,
              old_status: "pending",
              new_status: "approved",
              company_name: app_company&.name
            },
            created_at: trackable.updated_at
          )
        end
      elsif trackable.status == "rejected"
        has_rejected = db_activities.any? do |a|
          a.action == "rejected" ||
            (a.action == "status_changed" && (a.metadata&.dig("new_status") == "rejected" || a.description.to_s.downcase.include?("rejected")))
        end

        unless has_rejected
          rejector = (trackable.invoice_type == "purchase") ? creator : recipient_user
          rejector_name = rejector&.display_name || recipient_company_name.presence || "Customer"
          rej_company = (trackable.invoice_type == "purchase") ? creator_company : (recipient_company || creator_company)
          rej_date_str = trackable.updated_at.strftime("%b %-d")

          synthesized << Activity.new(
            trackable: trackable,
            user: rejector,
            user_name: rejector_name,
            user_email: rejector&.email,
            company: rej_company,
            company_name: rej_company&.name,
            action: "rejected",
            description: "#{rejector_name} marked Invoice as Rejected on #{rej_date_str}",
            metadata: {
              invoice_number: trackable.invoice_number,
              old_status: "pending",
              new_status: "rejected",
              company_name: rej_company&.name
            },
            created_at: trackable.updated_at
          )
        end
      end

      # 4. Paid Event (if marked as paid and no payment activities recorded)
      if trackable.status == "paid"
        has_paid = db_activities.any? do |a|
          %w[marked_as_paid invoice_paid].include?(a.action) ||
            (a.action == "status_changed" && (a.metadata&.dig("new_status") == "paid" || a.description.to_s.downcase.include?("paid"))) ||
            (a.action == "payment_recorded" && trackable.payments.empty?)
        end

        if !has_paid && trackable.payments.empty?
          paid_date_str = trackable.updated_at.strftime("%b %-d")
          payer_company = recipient_company || creator_company
          payer_company_name = payer_company&.name
          payer_user = recipient_user
          payer_name = payer_user&.display_name || (payer_company_name.present? ? payer_company_name : "Customer")

          synthesized << Activity.new(
            trackable: trackable,
            user: payer_user,
            user_name: payer_name,
            user_email: payer_user&.email,
            company: payer_company,
            company_name: payer_company_name,
            action: "marked_as_paid",
            description: "#{payer_name} marked Invoice as Paid on #{paid_date_str}",
            metadata: {
              invoice_number: trackable.invoice_number,
              company_name: payer_company_name,
              status: "paid"
            },
            created_at: trackable.updated_at
          )
        end
      end

      # 5. Payments (ensure all payments on the invoice are represented in the audit timeline)
      trackable.payments.each do |p|
        already_logged = db_activities.any? do |a|
          a.action == "payment_recorded" && (
            a.metadata&.dig("reference_number").to_s == p.reference_number.to_s ||
            (a.metadata&.dig("amount_paid").to_f == p.amount.to_f && (a.created_at.to_date == p.payment_date || a.metadata&.dig("payment_date").to_s == p.payment_date.to_s))
          )
        end

        unless already_logged
          p_user = p.user || creator
          p_name = p_user&.display_name || "User"
          p_company = p_user&.company || creator_company
          p_date_str = p.payment_date.strftime("%b %-d")
          status_label = (trackable.status == "paid") ? "Paid" : "Partially Paid"

          synthesized << Activity.new(
            trackable: trackable,
            user: p_user,
            user_name: p_name,
            user_email: p_user&.email,
            company: p_company,
            company_name: p_company&.name,
            action: "payment_recorded",
            description: "#{p_name} recorded a payment of #{p.formatted_amount} via #{p.payment_method} (Ref: #{p.reference_number}) marking Invoice as #{status_label} on #{p_date_str}",
            metadata: {
              invoice_number: trackable.invoice_number,
              status: trackable.status,
              amount_paid: p.amount.to_f,
              payment_method: p.payment_method,
              reference_number: p.reference_number,
              payment_date: p.payment_date.to_s,
              total_paid: trackable.total_paid,
              remaining_balance: trackable.remaining_balance
            },
            created_at: p.created_at || p.payment_date.to_time
          )
        end
      end

      # 6. Associated Tax Submissions (synthesize for baseline display when no DB activities exist)
      if db_activities.empty?
        trackable.tax_submissions.each do |sub|
        already_logged = db_activities.any? do |a|
          a.action == "tax_submitted" && (
            a.metadata&.dig("tax_submission_id") == sub.id ||
            a.metadata&.dig("transaction_id").to_s == (sub.company_submission_id || sub.user_transaction_id || sub.id).to_s
          )
        end

        unless already_logged
          sub_company = sub.company || recipient_company
          sub_company_name = sub_company&.name || sub.try(:company_name)
          user_by_email = sub.email.present? ? User.find_by(email: sub.email) : nil
          sub_user = user_by_email || sub_company&.user
          sub_name = if user_by_email.present? && user_by_email.id != trackable.user_id
                       user_by_email.display_name
                     elsif sub.email.present? && sub.email.to_s.downcase != creator&.email.to_s.downcase
                       sub.email.split("@").first.tr("._-", " ").titleize
                     elsif sub_user.present? && sub_user.id != trackable.user_id
                       sub_user.display_name
                     elsif sub_company_name.present? && sub_company_name != creator_company_name
                       sub_company_name
                     elsif sub.email.present?
                       sub.email.split("@").first.tr("._-", " ").titleize
                     else
                       sub_company_name.presence || "Customer"
                     end
          sub_date = sub.created_at.strftime("%b %-d")

          synthesized << Activity.new(
            trackable: trackable,
            user: sub_user,
            user_name: sub_name,
            user_email: sub.email.presence || sub_user&.email,
            company: sub_company,
            company_name: sub_company_name,
            action: "tax_submitted",
            description: "#{sub_name} submitted Form 2307 on #{sub_date}",
            metadata: {
              transaction_id: sub.company_submission_id || sub.user_transaction_id || sub.id,
              tax_submission_id: sub.id,
              company_name: sub_company_name,
              form_2307_attached: sub.form_2307.attached?,
              deposit_slip_attached: sub.deposit_slip.attached?
            },
            created_at: sub.created_at
          )
        end
      end
    end

    when TaxSubmission
      sub_company = trackable.company || trackable.invoice&.recipient_company
      sub_company_name = sub_company&.name || trackable.try(:company_name)
      submitter_user = (trackable.email.present? ? User.find_by(email: trackable.email) : nil) || sub_company&.user
      submitter_name = if submitter_user.present? && (!trackable.invoice || submitter_user.id != trackable.invoice.user_id)
                         submitter_user.display_name
                       elsif trackable.email.present? && (!trackable.invoice || trackable.email.to_s.downcase != trackable.invoice.user&.email.to_s.downcase)
                         trackable.email.split("@").first.tr("._-", " ").titleize
                       elsif sub_company_name.present?
                         sub_company_name
                       elsif trackable.email.present?
                         trackable.email.split("@").first.tr("._-", " ").titleize
                       else
                         sub_company_name.presence || "Submitter"
                       end
      sub_date = trackable.created_at.strftime("%b %-d")
      form_name = if trackable.form_2307.attached? && trackable.deposit_slip.attached?
                    "Form 2307 and Deposit Slip"
                  elsif trackable.form_2307.attached?
                    "Form 2307"
                  elsif trackable.deposit_slip.attached?
                    "Deposit Slip"
                  else
                    "Tax Documents"
                  end

      # 1. Submission event
      if db_activities.none? { |a| a.action == "tax_submitted" }
        synthesized << Activity.new(
          trackable: trackable,
          user: submitter_user,
          user_name: submitter_name,
          user_email: trackable.email,
          company: sub_company,
          company_name: sub_company_name,
          action: "tax_submitted",
          description: "#{submitter_name} submitted #{form_name} on #{sub_date}",
          metadata: {
            transaction_id: trackable.company_submission_id || trackable.user_transaction_id || trackable.id,
            invoice_number: trackable.invoice&.invoice_number,
            company_name: sub_company_name,
            form_2307_attached: trackable.form_2307.attached?,
            deposit_slip_attached: trackable.deposit_slip.attached?
          },
          created_at: trackable.created_at
        )
      end

      # 2. Reviewed event
      if trackable.reviewed? && db_activities.none? { |a| %w[reviewed marked_reviewed].include?(a.action) }
        rev_date = trackable.updated_at.strftime("%b %-d")
        rev_user = trackable.invoice&.user || trackable.invoice&.sale_from&.user
        rev_company = trackable.invoice&.sale_from || trackable.invoice&.user&.company || trackable.company
        rev_name = rev_user&.display_name || (rev_company&.name.present? ? "#{rev_company.name} Reviewer" : "Reviewer")
        synthesized << Activity.new(
          trackable: trackable,
          user: rev_user,
          user_name: rev_name,
          user_email: rev_user&.email,
          company: rev_company,
          company_name: rev_company&.name,
          action: "reviewed",
          description: "#{rev_name} marked submission as Reviewed on #{rev_date}",
          metadata: { field: "reviewed", new_value: true, company_name: rev_company&.name },
          created_at: trackable.updated_at
        )
      end

      # 3. Processed event
      if trackable.processed? && db_activities.none? { |a| %w[processed marked_processed].include?(a.action) }
        proc_date = trackable.updated_at.strftime("%b %-d")
        proc_user = trackable.invoice&.user || trackable.invoice&.sale_from&.user
        proc_company = trackable.invoice&.sale_from || trackable.invoice&.user&.company || trackable.company
        proc_name = proc_user&.display_name || (proc_company&.name.present? ? "#{proc_company.name} Processor" : "Processor")
        synthesized << Activity.new(
          trackable: trackable,
          user: proc_user,
          user_name: proc_name,
          user_email: proc_user&.email,
          company: proc_company,
          company_name: proc_company&.name,
          action: "processed",
          description: "#{proc_name} marked submission as Processed on #{proc_date}",
          metadata: { field: "processed", new_value: true, company_name: proc_company&.name },
          created_at: trackable.updated_at
        )
      end
    end

    all_activities = db_activities + synthesized
    sort_activities(all_activities)
  end

  def sort_activities(items)
    items.sort_by do |act|
      t = act.created_at || Time.current
      [t, action_chronological_weight(act.action)]
    end.reverse
  end

  def action_chronological_weight(action)
    case action.to_s
    when "invoice_created" then 0
    when "invoice_sent", "quote_sent" then 1
    when "approved", "rejected" then 2
    when "invoice_updated", "amount_updated" then 3
    when "payment_recorded", "payment_removed", "status_changed", "marked_as_paid", "invoice_paid" then 4
    when "tax_submitted" then 5
    when "reviewed", "processed" then 6
    else 7
    end
  end
end
