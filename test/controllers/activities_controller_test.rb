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
end
