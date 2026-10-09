require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_by(email: "jane_ctrl@example.com") || User.create!(
      email: "jane_ctrl@example.com",
      name: "Jane",
      password: "SecurePass#2026!xyz"
    )

    @other_user = User.find_by(email: "stranger_ctrl@example.com") || User.create!(
      email: "stranger_ctrl@example.com",
      name: "Stranger",
      password: "SecurePass#2026!xyz"
    )

    @company = Company.create!(name: "Acme Ctrl", user: @user)

    @invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-CTRL-01",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft",
      total: { "grand_total" => 1250.0 }
    )

    @tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "jane_ctrl@example.com",
      details: "Test submission"
    )
  end

  test "unauthenticated user cannot access activities" do
    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :redirect
  end

  test "returns bad request for invalid trackable_type" do
    sign_in @user
    get activities_url, params: { trackable_type: "MaliciousModel", trackable_id: 1 }
    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "authorized user can fetch invoice activity timeline" do
    sign_in @user

    ActivityLogger.log_invoice_created(@invoice, @user)
    ActivityLogger.log_invoice_amount_updated(@invoice, @user, 1000.0, 1250.0)

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "Invoice", json["trackable_type"]
    assert_equal @invoice.id, json["trackable_id"]
    assert_equal 2, json["activities_count"]

    first_activity = json["activities"].first
    assert_match /updated the invoice amount/, first_activity["description"]
    assert_equal "amount_updated", first_activity["action"]
    assert_equal "Jane", first_activity["actor_name"]
    assert_equal "Acme Ctrl", first_activity["company_name"]
  end

  test "unauthorized user cannot view invoice activity timeline" do
    sign_in @other_user
    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
  end

  test "authorized user can fetch tax submission activity timeline" do
    sign_in @user

    ActivityLogger.log_tax_submitted(@tax_submission, @user)

    get activities_url, params: { trackable_type: "TaxSubmission", trackable_id: @tax_submission.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal "TaxSubmission", json["trackable_type"]
    assert_not_empty json["activities"]
    assert_match /Jane submitted Form 2307/, json["activities"].first["description"]
  end

  test "unauthorized user cannot view tax submission activity timeline" do
    sign_in @other_user
    get activities_url, params: { trackable_type: "TaxSubmission", trackable_id: @tax_submission.id }
    assert_response :forbidden
  end

  test "synthesizes baseline creation activity if no records exist" do
    sign_in @user
    # Ensure invoice has no logged activities
    @invoice.activities.destroy_all

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_not_empty json["activities"]
    assert json["activities"].any? { |a| a["description"] =~ /created Invoice/ }
    assert_equal "Acme Ctrl", json["activities"].first["company_name"]
  end

  test "synthesizes distinct actors for creation, payment, and tax submission" do
    sign_in @user
    @invoice.activities.destroy_all

    recipient = Company.create!(name: "Client Buyer Corp", user: @other_user)
    @invoice.update!(status: "paid", recipient_company: recipient)
    TaxSubmission.create!(company: recipient, invoice: @invoice, email: "client_rep@example.com", details: "Filing 2307")

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    activities = json["activities"]

    creation_act = activities.find { |a| a["action"] == "invoice_created" }
    paid_act = activities.find { |a| a["action"] == "marked_as_paid" }
    tax_act = activities.find { |a| a["action"] == "tax_submitted" }

    assert_match /Jane created/, creation_act["description"]
    assert_equal "Acme Ctrl", creation_act["company_name"]

    assert_match /Client Buyer Corp|Stranger/, paid_act["description"]
    assert_no_match /Jane marked/, paid_act["description"]
    assert_equal "Client Buyer Corp", paid_act["company_name"]

    assert_match /Client Rep|Client Buyer Corp/, tax_act["description"]
    assert_no_match /Jane submitted/, tax_act["description"]
    assert_equal "Client Buyer Corp", tax_act["company_name"]
  end

  test "returns payment summary and payment receipts for invoice" do
    sign_in @user
    @invoice.update!(status: "sent")

    payment = @invoice.payments.create!(
      user: @user,
      payment_method: "Bank Transfer",
      reference_number: "TRN-TEST-123",
      payment_date: Date.current,
      amount: 500.0,
      notes: "First installment"
    )

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_not_nil json["payment_summary"]

    summary = json["payment_summary"]
    assert_equal 1250.0, summary["grand_total"]
    assert_equal 500.0, summary["total_paid"]
    assert_equal 750.0, summary["remaining_balance"]
    assert_equal 40, summary["percent_paid"]
    assert_equal 1, summary["payments_count"]
    assert_equal true, summary["can_record_payment"]

    first_payment = summary["payments"].first
    assert_equal payment.id, first_payment["id"]
    assert_equal "Bank Transfer", first_payment["payment_method"]
    assert_equal "TRN-TEST-123", first_payment["reference_number"]
    assert_equal 500.0, first_payment["amount"]
    assert_equal "First installment", first_payment["notes"]
  end

  test "timeline retains created and sent milestones even when payment activity is logged in DB" do
    sign_in @user
    @invoice.update!(status: "partially_paid")

    # Simulate only a payment activity being logged in the DB
    payment = @invoice.payments.create!(
      user: @user,
      payment_method: "GCash",
      reference_number: "GCASH-999",
      payment_date: Date.current,
      amount: 250.0
    )
    ActivityLogger.log_invoice_payment_recorded(@invoice, @user, payment)

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    activities = json["activities"]

    actions = activities.map { |a| a["action"] }
    assert_includes actions, "invoice_created", "Created milestone must be present"
    assert_includes actions, "invoice_sent", "Sent milestone must be present for partially_paid invoice"
    assert_includes actions, "payment_recorded", "Payment recorded event must be present"

    # Verify chronological order (most recent first)
    assert_equal "payment_recorded", activities.first["action"]
    assert_equal "invoice_created", activities.last["action"]
  end

  test "timeline includes approved milestone for approved invoices" do
    sign_in @user
    @invoice.update!(status: "approved")

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    actions = json["activities"].map { |a| a["action"] }

    assert_includes actions, "invoice_created"
    assert_includes actions, "invoice_sent"
    assert_includes actions, "approved"
  end

  test "timeline includes rejected milestone for rejected invoices" do
    sign_in @user
    @invoice.update!(status: "rejected")

    get activities_url, params: { trackable_type: "Invoice", trackable_id: @invoice.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    actions = json["activities"].map { |a| a["action"] }

    assert_includes actions, "invoice_created"
    assert_includes actions, "invoice_sent"
    assert_includes actions, "rejected"
  end
end
