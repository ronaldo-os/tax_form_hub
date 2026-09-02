require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "notif_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )

    @other_user = User.create!(
      email: "other_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )

    @notification1 = Notification.create!(
      recipient: @user,
      category: "invoices",
      action: "invoice_sent",
      title: "Invoice #1001 Sent",
      message: "Your invoice was successfully sent to client.",
      target_url: "/invoices/1"
    )

    @notification2 = Notification.create!(
      recipient: @user,
      category: "taxes",
      action: "tax_submitted",
      title: "BIR Form 2307 Filed",
      message: "Tax documentation has been submitted for review.",
      target_url: "/tax_submissions"
    )

    @other_notification = Notification.create!(
      recipient: @other_user,
      category: "invoices",
      action: "invoice_received",
      title: "Secret Other Notification",
      message: "Should not be accessible by @user."
    )
  end

  test "redirects unauthenticated users to sign up or login" do
    get notifications_path
    assert_response :redirect
  end

  test "authenticated user can view notifications index with categories and counts" do
    sign_in @user
    get notifications_path
    assert_response :success
    assert_select "#notifications_stat_cards"
    assert_select "#notification_row_#{@notification1.id}"
    assert_select "#notification_row_#{@notification2.id}"
    assert_select "#notification_row_#{@other_notification.id}", count: 0
  end

  test "filters notifications by category tab" do
    sign_in @user
    get notifications_path, params: { tab: "taxes" }
    assert_response :success
    assert_select "#notification_row_#{@notification2.id}"
    assert_select "#notification_row_#{@notification1.id}", count: 0
  end

  test "filters notifications by unread status" do
    sign_in @user
    @notification1.mark_as_read!

    get notifications_path, params: { status: "unread" }
    assert_response :success
    assert_select "#notification_row_#{@notification2.id}"
    assert_select "#notification_row_#{@notification1.id}", count: 0
  end

  test "filters notifications by search query" do
    sign_in @user
    get notifications_path, params: { q: "2307" }
    assert_response :success
    assert_select "#notification_row_#{@notification2.id}"
    assert_select "#notification_row_#{@notification1.id}", count: 0
  end

  test "can mark notification as read and unread" do
    sign_in @user
    assert @notification1.unread?

    patch mark_as_read_notification_path(@notification1)
    assert @notification1.reload.read?

    patch mark_as_unread_notification_path(@notification1)
    assert @notification1.reload.unread?
  end

  test "can mark all notifications as read" do
    sign_in @user
    assert_equal 2, @user.notifications.unread.count

    post mark_all_as_read_notifications_path
    assert_equal 0, @user.notifications.unread.count
  end

  test "can execute bulk action to mark multiple notifications" do
    sign_in @user
    post bulk_action_notifications_path, params: {
      bulk_action: "mark_read",
      notification_ids: [@notification1.id, @notification2.id]
    }

    assert @notification1.reload.read?
    assert @notification2.reload.read?
  end

  test "user cannot modify or view other users notifications" do
    sign_in @user
    patch mark_as_read_notification_path(@other_notification)
    assert_redirected_to notifications_path
    assert_not @other_notification.reload.read?
  end

  test "clicking notification marks it as read and redirects to target url" do
    sign_in @user
    assert @notification2.unread?

    get click_notification_path(@notification2)
    assert_response :see_other
    assert_redirected_to "/tax_submissions"
    assert @notification2.reload.read?
  end

  test "clicking invoice notification for counterpart invoice redirects to user's counterpart invoice" do
    seller_company = Company.create!(name: "Seller Co #{rand(1000)}", user: @other_user)
    buyer_company = Company.create!(name: "Buyer Co #{rand(1000)}", user: @user)

    seller_invoice = Invoice.create!(
      user: @other_user,
      invoice_number: "INV-CLICK-001",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: buyer_company
    )

    buyer_invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-CLICK-001",
      invoice_type: "purchase",
      invoice_category: "standard",
      sale_from: seller_company
    )

    # Notification has seller_invoice id stored in target_url, but recipient is @user
    notif = Notification.create!(
      recipient: @user,
      actor: @other_user,
      category: "invoices",
      action: "invoice_sent",
      title: "Invoice Sent",
      target_url: "/invoices/#{seller_invoice.id}"
    )

    sign_in @user
    get click_notification_path(notif)
    assert_response :see_other
    assert_redirected_to "/invoices/#{buyer_invoice.id}"
    assert notif.reload.read?
  end
end
