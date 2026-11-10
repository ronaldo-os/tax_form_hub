require "test_helper"

class BreadcrumbsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "breadcrumbs_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Acme Holdings", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "top-level dashboard does not render breadcrumbs" do
    get root_path
    assert_response :success
    assert_select ".app-breadcrumbs-nav", 0
  end

  test "deep page invoices/new renders breadcrumbs with parent link" do
    get new_invoice_path
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href*='/invoices']", text: "Invoices"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "New Invoice"
  end

  test "deep page invoices/show renders breadcrumbs" do
    invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-BREADCRUMB-001",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: @company,
      currency: "PHP",
      issue_date: Date.current,
      payment_terms: { "cash" => { "cash.description" => "Cash on delivery" } }
    )

    get invoice_path(invoice)
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href*='/invoices']", text: "Invoices"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "INV-BREADCRUMB-001"
  end

  test "deep page invoices/edit renders 3-level breadcrumbs" do
    invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-BREADCRUMB-002",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: @company,
      currency: "PHP",
      issue_date: Date.current,
      payment_terms: { "cash" => { "cash.description" => "Cash on delivery" } }
    )

    get edit_invoice_path(invoice)
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href*='/invoices']", text: "Invoices"
    assert_select ".breadcrumb-item a[href*='/invoices/#{invoice.id}']", text: "INV-BREADCRUMB-002"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "Edit"
  end

  test "deep page subscriptions/show renders breadcrumbs" do
    subscription = Invoice.create!(
      user: @user,
      invoice_number: "SUB-BREADCRUMB-001",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: @company,
      currency: "PHP",
      issue_date: Date.current,
      payment_terms: { "cash" => { "cash.description" => "Cash" } },
      line_items_data: [
        {
          "item_id" => "101",
          "description" => "Monthly Retainer",
          "quantity" => 1,
          "price" => 1000,
          "tax" => "0",
          "optional_fields" => {
            "subscription_start_date" => Date.current.to_s,
            "subscription_end_date" => (Date.current + 6.months).to_s,
            "subscription_billing_cycle" => "monthly"
          }
        }
      ]
    )

    get subscription_path(subscription)
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href*='/subscriptions']", text: "Subscriptions"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "SUB-BREADCRUMB-001"
  end

  test "deep page incoming tax submissions renders breadcrumbs" do
    get tax_submissions_path
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href*='/tax_submissions/home']", text: "Taxes"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "Incoming Submissions"
  end

  test "deep page edit profile renders breadcrumbs" do
    get edit_profile_path
    assert_response :success
    assert_select ".app-breadcrumbs-nav"
    assert_select ".breadcrumb-item a[href='/']"
    assert_select ".breadcrumb-item.active .breadcrumb-current", text: "User Profile"
  end
end
