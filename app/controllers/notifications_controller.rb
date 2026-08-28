class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:mark_as_read, :mark_as_unread, :click]

  def dropdown
    render partial: "layouts/notification_dropdown", locals: { user: current_user }
  end

  def mark_as_read
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("header_notification_dropdown_container", partial: "layouts/notification_dropdown", locals: { user: current_user })
      end
      format.json { render json: { success: true, unread_count: current_user.notifications.unread.count } }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def mark_as_unread
    @notification.mark_as_unread!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("header_notification_dropdown_container", partial: "layouts/notification_dropdown", locals: { user: current_user })
      end
      format.json { render json: { success: true, unread_count: current_user.notifications.unread.count } }
      format.html { redirect_back fallback_location: root_path }
    end
  end

  def click
    @notification.mark_as_read!
    target = @notification.target_url.presence || root_path
    redirect_to target, status: :see_other
  end

  def mark_all_as_read
    current_user.notifications.unread.update_all(read_at: Time.current, updated_at: Time.current)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("header_notification_dropdown_container", partial: "layouts/notification_dropdown", locals: { user: current_user })
      end
      format.json { render json: { success: true, unread_count: 0 } }
      format.html { redirect_back fallback_location: root_path, notice: "All notifications marked as read." }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find_by(id: params[:id])
    unless @notification
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Notification not found." }
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.turbo_stream { head :not_found }
      end
    end
  end
end
