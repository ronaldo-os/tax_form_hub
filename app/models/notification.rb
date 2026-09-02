class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :recipient_id, :category, :action, :title, presence: true

  enum :category, {
    invoices: "invoices",
    taxes: "taxes",
    system: "system"
  }

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_category, ->(cat) { where(category: cat) if cat.present? && !%w[all unread read].include?(cat.to_s) }

  after_create_commit :broadcast_creation
  after_update_commit :broadcast_update
  after_destroy_commit :broadcast_destruction

  def read?
    read_at.present?
  end

  def unread?
    read_at.nil?
  end

  def mark_as_read!
    update(read_at: Time.current) if unread?
  end

  def mark_as_unread!
    update(read_at: nil) if read?
  end

  # Dynamically resolve target_url to the recipient's viewable resource
  def target_url
    raw_url = read_attribute(:target_url)
    return "/notifications" if raw_url.blank?

    # Resolve invoice target URLs if recipient doesn't directly own the invoice ID
    if (match = raw_url.match(%r{\A/invoices/(\d+)\z}))
      inv_id = match[1].to_i
      if recipient&.invoices&.exists?(id: inv_id)
        return raw_url
      end

      # Find by ID and look up counterpart invoice for recipient
      inv = Invoice.find_by(id: inv_id)
      if inv && recipient
        target_type = (inv.invoice_type == "sale" ? "purchase" : "sale")
        counterpart = recipient.invoices.find_by(
          invoice_number: inv.invoice_number,
          invoice_type: target_type
        ) || recipient.invoices.find_by(invoice_number: inv.invoice_number)
        return "/invoices/#{counterpart.id}" if counterpart
      end
    end

    # Handle tax submission paths for non-admin vs admin
    if raw_url.start_with?("/admin/tax_submissions") && recipient&.role != "superadmin"
      return "/tax_submissions"
    end

    raw_url
  end

  # Returns icon configuration for UI rendering based on category and action
  def icon_config
    case action
    when "invoice_sent", "invoice_received"
      { icon: "fa-solid fa-file-invoice-dollar", color: "text-primary", bg: "bg-primary-subtle" }
    when "quote_sent", "quote_received"
      { icon: "fa-solid fa-file-lines", color: "text-info", bg: "bg-info-subtle" }
    when "invoice_approved", "quote_approved"
      { icon: "fa-solid fa-circle-check", color: "text-success", bg: "bg-success-subtle" }
    when "invoice_rejected", "quote_rejected"
      { icon: "fa-solid fa-circle-xmark", color: "text-danger", bg: "bg-danger-subtle" }
    when "invoice_paid"
      { icon: "fa-solid fa-circle-dollar-to-slot", color: "text-success", bg: "bg-success-subtle" }
    when "credit_note_created"
      { icon: "fa-solid fa-receipt", color: "text-warning", bg: "bg-warning-subtle" }
    when "tax_submitted", "tax_submitted_admin"
      { icon: "fa-solid fa-file-arrow-up", color: "text-primary", bg: "bg-primary-subtle" }
    when "tax_reviewed"
      { icon: "fa-solid fa-file-circle-check", color: "text-success", bg: "bg-success-subtle" }
    when "tax_processed"
      { icon: "fa-solid fa-clipboard-check", color: "text-success", bg: "bg-success-subtle" }
    when "tax_status_updated"
      { icon: "fa-solid fa-bell", color: "text-info", bg: "bg-info-subtle" }
    else
      if category == "taxes"
        { icon: "fa-solid fa-file-invoice-dollar", color: "text-success", bg: "bg-success-subtle" }
      elsif category == "invoices"
        { icon: "fa-solid fa-file-invoice", color: "text-primary", bg: "bg-primary-subtle" }
      else
        { icon: "fa-solid fa-bell", color: "text-secondary", bg: "bg-secondary-subtle" }
      end
    end
  end

  private

  def broadcast_creation
    # Broadcast replace to header dropdown
    broadcast_replace_to(
      "user_#{recipient_id}_notifications",
      target: "header_notification_dropdown_container",
      partial: "layouts/notification_dropdown",
      locals: { user: recipient }
    )

    # Broadcast real-time toast alert pop-up
    broadcast_prepend_to(
      "user_#{recipient_id}_notifications",
      target: "live_notification_toasts",
      partial: "notifications/toast",
      locals: { notification: self }
    )
  rescue StandardError => e
    Rails.logger.error "Notification broadcast error on create: #{e.message}"
  end

  def broadcast_update
    broadcast_replace_to(
      "user_#{recipient_id}_notifications",
      target: "header_notification_dropdown_container",
      partial: "layouts/notification_dropdown",
      locals: { user: recipient }
    )
  rescue StandardError => e
    Rails.logger.error "Notification broadcast error on update: #{e.message}"
  end

  def broadcast_destruction
    broadcast_replace_to(
      "user_#{recipient_id}_notifications",
      target: "header_notification_dropdown_container",
      partial: "layouts/notification_dropdown",
      locals: { user: recipient }
    )
  rescue StandardError => e
    Rails.logger.error "Notification broadcast error on destroy: #{e.message}"
  end
end
