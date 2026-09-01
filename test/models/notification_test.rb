require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by(email: "test_notif@example.com") || User.create!(email: "test_notif@example.com", password: "SecurePass#2026!xyz")
    @actor = User.find_by(email: "actor_notif@example.com") || User.create!(email: "actor_notif@example.com", password: "SecurePass#2026!xyz")
  end

  test "can create notification and query unread" do
    notif = Notification.create!(
      recipient: @user,
      actor: @actor,
      category: "invoices",
      action: "invoice_sent",
      title: "New Invoice #1001",
      message: "You have a new invoice",
      target_url: "/invoices/1"
    )

    assert notif.persisted?
    assert notif.unread?
    assert_not notif.read?
    assert_includes @user.notifications.unread, notif

    notif.mark_as_read!
    assert notif.read?
    assert_not_includes @user.notifications.unread, notif

    notif.mark_as_unread!
    assert notif.unread?
    assert_not notif.read?
  end

  test "notification service creates notifications correctly" do
    assert_difference("Notification.count", 1) do
      NotificationService.notify(
        recipient: @user,
        actor: @actor,
        category: :taxes,
        action: "tax_submitted",
        title: "BIR Form 2307 Received",
        message: "Tax filing documents submitted",
        target_url: "/tax_submissions"
      )
    end

    latest = @user.notifications.recent.first
    assert_equal "taxes", latest.category
    assert_equal "tax_submitted", latest.action
    assert_equal "BIR Form 2307 Received", latest.title
  end
end
