require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "dashboard_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Dashboard Test Corp #{Time.now.to_i}", user: @user)
    @user.update(company: @company)

    # Customer Company
    @other_user = User.create!(
      email: "partner_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @partner_company = Company.create!(name: "Acme Client Inc", user: @other_user)

    # Seed sales invoice
    @sale_invoice = Invoice.create!(
      user: @user,
      recipient_company: @partner_company,
      invoice_number: "INV-2026-001",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "paid",
      currency: "USD",
      issue_date: Date.current,
      total: { "grand_total" => "5000.00", "subtotal" => "4500.00", "tax_amount" => "500.00" }
    )

    # Seed purchase bill
    @purchase_invoice = Invoice.create!(
      user: @user,
      sale_from: @partner_company,
      invoice_number: "BILL-2026-001",
      invoice_type: "purchase",
      invoice_category: "standard",
      status: "approved",
      currency: "USD",
      issue_date: Date.current,
      total: { "grand_total" => "2000.00", "subtotal" => "1800.00", "tax_amount" => "200.00" }
    )
  end

  test "unauthenticated user is redirected to sign in when visiting root" do
    get root_url
    assert_response :redirect
    assert_redirected_to new_user_session_url
  end

  test "authenticated user successfully accesses interactive dashboard at root" do
    sign_in @user
    get root_url
    assert_response :success
    assert_select "h2", text: /Dashboard Test Corp/
    assert_select "div#analytics_dashboard_container"
    assert_select "div#kpi_cards_ribbon"
    assert_select "canvas#performanceTrendChart"
    assert_select "canvas#statusDonutChart"
    assert_select "canvas#taxComplianceChart"
  end

  test "analytics_data JSON endpoint returns calculated KPI metrics and charts" do
    sign_in @user
    get dashboards_analytics_data_url(time_frame: "this_month", currency: "USD", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("kpis")
    assert json.key?("charts")
    assert json.key?("recent_invoices")

    kpis = json["kpis"]
    assert_equal 5000.0, kpis["total_sales_revenue"]
    assert_equal 2000.0, kpis["total_purchases_expense"]
    assert_equal 3000.0, kpis["net_operating_income"]
    assert_equal 1, kpis["total_sales_count"]
    assert_equal 1, kpis["total_purchases_count"]
  end

  test "analytics_data respects time_frame filters" do
    sign_in @user
    get dashboards_analytics_data_url(time_frame: "7d", currency: "all", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "7d", json["time_frame"]
    assert_equal "Last 7 Days", json["range_label"]
    assert json["charts"]["trends"]["labels"].present?
  end

  test "user data isolation prevents seeing other users invoices in dashboard metrics" do
    # Create another isolated user with massive revenue
    isolated_user = User.create!(
      email: "isolated_#{Time.now.to_i}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    Invoice.create!(
      user: isolated_user,
      invoice_number: "SECRET-001",
      invoice_type: "sale",
      status: "paid",
      currency: "USD",
      issue_date: Date.current,
      total: { "grand_total" => "999999.00" }
    )

    sign_in @user
    get dashboards_analytics_data_url(time_frame: "all_time", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 5000.0, json["kpis"]["total_sales_revenue"]
    assert_no_match(/SECRET-001/, response.body)
  end
end
