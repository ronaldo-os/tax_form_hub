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

    activities = trackable.activities.recent.includes(:user).to_a

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

      # 1. Creation event
      items << Activity.new(
        trackable: trackable,
        user: trackable.user,
        user_name: creator_name,
        user_email: trackable.user&.email,
        action: "invoice_created",
        description: "#{creator_name} created #{category_name} ##{trackable.invoice_number} on #{date_str}",
        metadata: {
          invoice_number: trackable.invoice_number,
          total: trackable.grand_total,
          currency: trackable.currency
        },
        created_at: trackable.created_at
      )

      # 2. Paid event if invoice is paid
      if trackable.status == "paid"
        paid_date_str = trackable.updated_at.strftime("%b %-d")
        items << Activity.new(
          trackable: trackable,
          user: trackable.user,
          user_name: creator_name,
          user_email: trackable.user&.email,
          action: "marked_as_paid",
          description: "#{creator_name} marked Invoice as Paid on #{paid_date_str}",
          metadata: {
            invoice_number: trackable.invoice_number,
            status: "paid"
          },
          created_at: trackable.updated_at
        )
      end

      # 3. Associated Tax Submissions
      trackable.tax_submissions.each do |sub|
        sub_name = sub.email.present? ? sub.email.split("@").first.tr("._-", " ").titleize : "Jane"
        sub_date = sub.created_at.strftime("%b %-d")
        items << Activity.new(
          trackable: trackable,
          user_name: sub_name,
          user_email: sub.email,
          action: "tax_submitted",
          description: "#{sub_name} submitted Form 2307 on #{sub_date}",
          metadata: {
            transaction_id: sub.company_submission_id || sub.user_transaction_id || sub.id,
            form_2307_attached: sub.form_2307.attached?,
            deposit_slip_attached: sub.deposit_slip.attached?
          },
          created_at: sub.created_at
        )
      end

    when TaxSubmission
      submitter_name = trackable.email.present? ? trackable.email.split("@").first.tr("._-", " ").titleize : "Jane"
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
        user_name: submitter_name,
        user_email: trackable.email,
        action: "tax_submitted",
        description: "#{submitter_name} submitted #{form_name} on #{sub_date}",
        metadata: {
          transaction_id: trackable.company_submission_id || trackable.user_transaction_id || trackable.id,
          invoice_number: trackable.invoice&.invoice_number,
          form_2307_attached: trackable.form_2307.attached?,
          deposit_slip_attached: trackable.deposit_slip.attached?
        },
        created_at: trackable.created_at
      )

      # 2. Reviewed event
      if trackable.reviewed?
        rev_date = trackable.updated_at.strftime("%b %-d")
        items << Activity.new(
          trackable: trackable,
          user_name: "Reviewer",
          action: "reviewed",
          description: "Reviewer marked submission as Reviewed on #{rev_date}",
          metadata: { field: "reviewed", new_value: true },
          created_at: trackable.updated_at
        )
      end

      # 3. Processed event
      if trackable.processed?
        proc_date = trackable.updated_at.strftime("%b %-d")
        items << Activity.new(
          trackable: trackable,
          user_name: "Processor",
          action: "processed",
          description: "Processor marked submission as Processed on #{proc_date}",
          metadata: { field: "processed", new_value: true },
          created_at: trackable.updated_at
        )
      end
    end

    # Sort descending by created_at
    items.sort_by(&:created_at).reverse
  end
end
