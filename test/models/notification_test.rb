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

  test "target_url dynamically resolves counterpart invoice if recipient owns different invoice record" do
    seller_company = Company.create!(name: "Seller Co #{rand(1000)}", user: @actor)
    buyer_company = Company.create!(name: "Buyer Co #{rand(1000)}", user: @user)

    seller_invoice = Invoice.create!(
      user: @actor,
      invoice_number: "INV-TEST-001",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: buyer_company
    )

    buyer_invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-TEST-001",
      invoice_type: "purchase",
      invoice_category: "standard",
      sale_from: seller_company
    )

    # Notification created with seller_invoice ID, but recipient is @user (buyer)
    notif = Notification.create!(
      recipient: @user,
      actor: @actor,
      category: "invoices",
      action: "invoice_sent",
      title: "Invoice Sent",
      target_url: "/invoices/#{seller_invoice.id}"
    )

    # Calling target_url on notif should resolve to buyer_invoice.id for @user
    assert_equal "/invoices/#{buyer_invoice.id}", notif.target_url
  end

  test "notification service resolves correct invoice when notifying sender on approval" do
    seller_company = Company.create!(name: "Seller Co 2 #{rand(1000)}", user: @actor)
    buyer_company = Company.create!(name: "Buyer Co 2 #{rand(1000)}", user: @user)

    seller_invoice = Invoice.create!(
      user: @actor,
      invoice_number: "INV-TEST-002",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: buyer_company
    )

    buyer_invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-TEST-002",
      invoice_type: "purchase",
      invoice_category: "standard",
      sale_from: seller_company
    )

    # Buyer approves buyer_invoice -> NotificationService notifies seller (@actor)
    NotificationService.notify_invoice_approved(buyer_invoice, @actor, @user)

    notif = @actor.notifications.recent.first
    assert_equal "invoice_approved", notif.action
    assert_equal "/invoices/#{seller_invoice.id}", notif.target_url
  end
end
