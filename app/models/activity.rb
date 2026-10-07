# frozen_string_literal: true

class Activity < ApplicationRecord
  belongs_to :trackable, polymorphic: true
  belongs_to :user, optional: true

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :chronological, -> { order(created_at: :asc) }
  scope :for_trackable, ->(trackable) { where(trackable: trackable) }

  before_validation :cache_actor_details, on: :create

  def actor_name
    user_name.presence || user&.display_name || user_email&.split("@")&.first&.tr("._-", " ")&.titleize || "System"
  end

  def actor_initial
    actor_name.strip.first&.upcase || "A"
  end

  def formatted_date
    created_at.strftime("%b %-d")
  end

  def formatted_date_with_year
    created_at.strftime("%b %-d, %Y")
  end

  def formatted_time
    created_at.strftime("%I:%M %p")
  end

  def formatted_full_date
    created_at.strftime("%b %-d, %Y at %I:%M %p")
  end

  def time_ago
    seconds = (Time.current - created_at).to_i
    if seconds < 60
      "just now"
    elsif seconds < 3600
      "#{seconds / 60}m ago"
    elsif seconds < 86400
      "#{seconds / 3600}h ago"
    elsif seconds < 604800
      "#{seconds / 86400}d ago"
    else
      formatted_date_with_year
    end
  end

  def icon_config
    case action
    when "tax_submitted", "tax_documents_submitted"
      { icon: "fa-solid fa-file-invoice", color_class: "timeline-icon-info", badge_class: "bg-info-subtle text-info border border-info-subtle", label: "Tax Submitted" }
    when "marked_as_paid", "invoice_paid"
      { icon: "fa-solid fa-circle-check", color_class: "timeline-icon-success", badge_class: "bg-success-subtle text-success border border-success-subtle", label: "Paid" }
    when "amount_updated"
      { icon: "fa-solid fa-pen-to-square", color_class: "timeline-icon-warning", badge_class: "bg-warning-subtle text-warning border border-warning-subtle", label: "Amount Updated" }
    when "invoice_created"
      { icon: "fa-solid fa-file-circle-plus", color_class: "timeline-icon-primary", badge_class: "bg-primary-subtle text-primary border border-primary-subtle", label: "Created" }
    when "invoice_updated"
      { icon: "fa-solid fa-pencil", color_class: "timeline-icon-secondary", badge_class: "bg-secondary-subtle text-secondary border border-secondary-subtle", label: "Updated" }
    when "status_changed"
      { icon: "fa-solid fa-arrows-rotate", color_class: "timeline-icon-primary", badge_class: "bg-primary-subtle text-primary border border-primary-subtle", label: "Status Changed" }
    when "invoice_sent", "quote_sent"
      { icon: "fa-solid fa-paper-plane", color_class: "timeline-icon-info", badge_class: "bg-info-subtle text-info border border-info-subtle", label: "Sent" }
    when "reviewed", "marked_reviewed"
      { icon: "fa-solid fa-clipboard-check", color_class: "timeline-icon-info", badge_class: "bg-info-subtle text-info border border-info-subtle", label: "Reviewed" }
    when "processed", "marked_processed"
      { icon: "fa-solid fa-circle-check", color_class: "timeline-icon-success", badge_class: "bg-success-subtle text-success border border-success-subtle", label: "Processed" }
    when "archived"
      { icon: "fa-solid fa-box-archive", color_class: "timeline-icon-secondary", badge_class: "bg-secondary-subtle text-secondary border border-secondary-subtle", label: "Archived" }
    when "unarchived"
      { icon: "fa-solid fa-box-open", color_class: "timeline-icon-success", badge_class: "bg-success-subtle text-success border border-success-subtle", label: "Unarchived" }
    when "credit_note_created"
      { icon: "fa-solid fa-receipt", color_class: "timeline-icon-warning", badge_class: "bg-warning-subtle text-warning border border-warning-subtle", label: "Credit Note" }
    else
      { icon: "fa-solid fa-clock-rotate-left", color_class: "timeline-icon-secondary", badge_class: "bg-secondary-subtle text-secondary border border-secondary-subtle", label: action.to_s.humanize }
    end
  end

  private

  def cache_actor_details
    if user.present?
      self.user_name ||= user.display_name
      self.user_email ||= user.email
    end
  end
end
