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

    activities = trackable.activities.recent.includes(:user, :company).to_a

    if activities.empty?
      activities = synthesize_baseline_activities(trackable)
    end

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

    render json: {
      success: true,
      trackable_type: trackable_type,
      trackable_id: trackable.id,
      resource_title: resource_title,
      resource_number: resource_number,
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

  def synthesize_baseline_activities(trackable)
    items = []

    case trackable
    when Invoice
      creator_name = trackable.user&.display_name || "User"
      date_str = trackable.created_at.strftime("%b %-d")
      category_name = trackable.standard? ? "Invoice" : trackable.invoice_category.humanize
      creator_company = trackable.sale_from || trackable.user&.company || trackable.user&.companies&.first
      creator_company_name = creator_company&.name

      # 1. Creation event
      items << Activity.new(
        trackable: trackable,
        user: trackable.user,
        user_name: creator_name,
        user_email: trackable.user&.email,
        company: creator_company,
        company_name: creator_company_name,
        action: "invoice_created",
        description: "#{creator_name} created #{category_name} ##{trackable.invoice_number} on #{date_str}",
        metadata: {
          invoice_number: trackable.invoice_number,
          company_name: creator_company_name,
          total: trackable.grand_total,
          currency: trackable.currency
        },
        created_at: trackable.created_at
      )

      # 2. Paid event if invoice is paid
      if trackable.status == "paid"
        paid_date_str = trackable.updated_at.strftime("%b %-d")
        payer_company = trackable.recipient_company || creator_company
        payer_company_name = payer_company&.name
        payer_user = trackable.recipient_company&.user
        payer_name = payer_user&.display_name || (payer_company_name.present? ? payer_company_name : "Customer")
        items << Activity.new(
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

      # 3. Associated Tax Submissions
      trackable.tax_submissions.each do |sub|
        sub_company = sub.company || trackable.recipient_company
        sub_company_name = sub_company&.name || sub.try(:company_name)
        sub_user = (sub.email.present? ? User.find_by(email: sub.email) : nil) || sub_company&.user
        sub_name = if sub_user.present? && sub_user.id != trackable.user_id
                     sub_user.display_name
                   elsif sub.email.present? && sub.email.to_s.downcase != trackable.user&.email.to_s.downcase
                     sub.email.split("@").first.tr("._-", " ").titleize
                   elsif sub_company_name.present? && sub_company_name != creator_company_name
                     sub_company_name
                   elsif sub.email.present?
                     sub.email.split("@").first.tr("._-", " ").titleize
                   else
                     sub_company_name.presence || "Customer"
                   end
        sub_date = sub.created_at.strftime("%b %-d")
        items << Activity.new(
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
            company_name: sub_company_name,
            form_2307_attached: sub.form_2307.attached?,
            deposit_slip_attached: sub.deposit_slip.attached?
          },
          created_at: sub.created_at
        )
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
      items << Activity.new(
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

      # 2. Reviewed event
      if trackable.reviewed?
        rev_date = trackable.updated_at.strftime("%b %-d")
        rev_user = trackable.invoice&.user || trackable.invoice&.sale_from&.user
        rev_company = trackable.invoice&.sale_from || trackable.invoice&.user&.company || trackable.company
        rev_name = rev_user&.display_name || (rev_company&.name.present? ? "#{rev_company.name} Reviewer" : "Reviewer")
        items << Activity.new(
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
      if trackable.processed?
        proc_date = trackable.updated_at.strftime("%b %-d")
        proc_user = trackable.invoice&.user || trackable.invoice&.sale_from&.user
        proc_company = trackable.invoice&.sale_from || trackable.invoice&.user&.company || trackable.company
        proc_name = proc_user&.display_name || (proc_company&.name.present? ? "#{proc_company.name} Processor" : "Processor")
        items << Activity.new(
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

    # Sort descending by created_at
    items.sort_by(&:created_at).reverse
  end
end
