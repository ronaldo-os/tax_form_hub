class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:mark_as_read, :mark_as_unread, :destroy, :click]
  before_action :set_summary_counts, only: [:index, :mark_as_read, :mark_as_unread, :destroy, :mark_all_as_read, :bulk_action]

  def index
    load_notifications

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json { render json: @notifications }
    end
  end

  def dropdown
    render partial: "layouts/notification_dropdown", locals: { user: current_user }
  end

  def mark_as_read
    @notification.mark_as_read!
    set_summary_counts

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true, unread_count: @unread_count } }
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def mark_as_unread
    @notification.mark_as_unread!
    set_summary_counts

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true, unread_count: @unread_count } }
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def destroy
    @notification.destroy
    set_summary_counts

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true } }
      format.html { redirect_back fallback_location: notifications_path, notice: "Notification deleted." }
    end
  end

  def mark_all_as_read
    target_scope = current_user.notifications.unread
    category = params[:category]
    if category.present? && %w[invoices taxes system].include?(category)
      target_scope = target_scope.where(category: category)
    end

    target_scope.update_all(read_at: Time.current, updated_at: Time.current)
    set_summary_counts
    load_notifications

    respond_to do |format|
      format.turbo_stream { render :bulk_action }
      format.json { render json: { success: true, unread_count: @unread_count } }
      format.html { redirect_back fallback_location: notifications_path, notice: "Notifications marked as read." }
    end
  end

  def bulk_action
    action_type = params[:bulk_action]
    ids = Array(params[:notification_ids]).map(&:to_i).reject(&:zero?)
    scoped_notifs = current_user.notifications.where(id: ids)

    if scoped_notifs.any?
      case action_type
      when "mark_read"
        scoped_notifs.where(read_at: nil).update_all(read_at: Time.current, updated_at: Time.current)
      when "mark_unread"
        scoped_notifs.where.not(read_at: nil).update_all(read_at: nil, updated_at: Time.current)
      when "destroy"
        scoped_notifs.destroy_all
      end
    end

    set_summary_counts
    load_notifications

    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true, count: scoped_notifs.count } }
      format.html { redirect_back fallback_location: notifications_path, notice: "Bulk action applied successfully." }
    end
  end

  def click
    @notification.mark_as_read!
    target = @notification.target_url.presence || notifications_path
    
    # Ensure open redirect protection: only relative paths or safe local paths
    if target.start_with?("/") && !target.start_with?("//")
      redirect_to target, status: :see_other
    else
      redirect_to notifications_path, status: :see_other
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find_by(id: params[:id])
    unless @notification
      respond_to do |format|
        format.html { redirect_to notifications_path, alert: "Notification not found." }
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.turbo_stream { head :not_found }
      end
    end
  end

  def set_summary_counts
    all_notifs = current_user.notifications
    @total_count = all_notifs.count
    @unread_count = all_notifs.unread.count
    @read_count = all_notifs.read.count
    @invoices_count = all_notifs.for_category("invoices").count
    @taxes_count = all_notifs.for_category("taxes").count
    @system_count = all_notifs.for_category("system").count
  end

  def load_notifications
    @tab = params[:tab].presence || "all"
    @status = params[:status].presence || "all"
    @query = params[:q].to_s.strip

    base_scope = current_user.notifications

    # Category filter
    if %w[invoices taxes system].include?(@tab)
      base_scope = base_scope.where(category: @tab)
    end

    # Read/Unread filter
    case @status
    when "unread"
      base_scope = base_scope.where(read_at: nil)
    when "read"
      base_scope = base_scope.where.not(read_at: nil)
    end

    # Search filter
    if @query.present?
      search_term = "%#{@query}%"
      base_scope = base_scope.where("title ILIKE :q OR message ILIKE :q", q: search_term)
    end

    @notifications = base_scope.includes(:actor).recent.limit(100)
  end
end
