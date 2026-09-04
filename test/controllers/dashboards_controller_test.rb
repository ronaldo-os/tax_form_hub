require "test_helper"

class DashboardsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "dashboard_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      currency: "USD"
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
    assert_equal 5000.0, kpis["paid_sales_revenue"]
    assert_equal 2000.0, kpis["total_purchases_expense"]
    assert_equal 0.0, kpis["paid_purchases_expense"] # purchase was 'approved', not 'paid'
    assert_equal 2000.0, kpis["total_payables"]
    assert_equal 3000.0, kpis["net_operating_income"]
    assert_equal 5000.0, kpis["net_cash_flow"] # 5000 paid sales - 0 paid purchases
    assert_equal 60.0, kpis["profit_margin"] # (3000 / 5000) * 100
    assert_equal 5000.0, kpis["avg_sale_invoice_value"]
    assert_equal 2000.0, kpis["avg_purchase_bill_value"]
    assert_equal 100.0, kpis["sales_collection_rate"]
    assert_equal 0.0, kpis["purchases_settlement_rate"]
    assert_equal 500.0, kpis["total_tax_sales"]
    assert_equal 200.0, kpis["total_tax_purchases"]
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

  test "recurring invoices calculation is only added when recurring invoices are sent to the account (purchase/received) and not when they are the sender" do
    # 1. User sends an outgoing recurring sales contract (they are the sender)
    Invoice.create!(
      user: @user,
      recipient_company: @partner_company,
      invoice_number: "REC-SALE-001",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "sent",
      currency: "USD",
      issue_date: Date.current,
      recurring_parent_invoice_id: nil,
      line_items_data: [
        {
          "description" => "Monthly Retainer",
          "quantity" => "1",
          "price" => "1000.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "billing_cycle" => "monthly",
              "start_date" => Date.current.to_s
            }
          }
        }
      ],
      total: { "grand_total" => "1000.00", "subtotal" => "1000.00" }
    )

    sign_in @user
    get dashboards_analytics_data_url(time_frame: "this_month", currency: "USD", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    # The outgoing recurring sales contract sent by @user is NOT added to recurring subscription count / MRR
    assert_equal 0, json["kpis"]["active_subscriptions_count"]
    assert_equal 0.0, json["kpis"]["total_mrr"]
    assert_equal 0.0, json["kpis"]["total_arr"]

    # 2. An incoming recurring contract is sent to @user (purchase recurring invoice sent to them)
    Invoice.create!(
      user: @user,
      sale_from: @partner_company,
      invoice_number: "REC-PURCH-001",
      invoice_type: "purchase",
      invoice_category: "standard",
      status: "pending",
      currency: "USD",
      issue_date: Date.current,
      recurring_parent_invoice_id: nil,
      line_items_data: [
        {
          "description" => "Software Subscription",
          "quantity" => "1",
          "price" => "500.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "billing_cycle" => "monthly",
              "start_date" => Date.current.to_s
            }
          }
        }
      ],
      total: { "grand_total" => "500.00", "subtotal" => "500.00" }
    )

    get dashboards_analytics_data_url(time_frame: "this_month", currency: "USD", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    # Now the recurring invoice sent to them is included
    assert_equal 1, json["kpis"]["active_subscriptions_count"]
    assert_equal 500.0, json["kpis"]["total_mrr"]
    assert_equal 6000.0, json["kpis"]["total_arr"]
    assert_equal 500.0, json["kpis"]["avg_mrr_per_subscription"]
  end

  test "dashboard automatically defaults to user preferred currency from profile" do
    @user.update!(currency: "EUR")
    Invoice.create!(
      user: @user,
      recipient_company: @partner_company,
      invoice_number: "INV-EUR-001",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "paid",
      currency: "EUR",
      issue_date: Date.current,
      total: { "grand_total" => "7500.00" }
    )

    sign_in @user
    get dashboards_analytics_data_url(time_frame: "this_month", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "EUR", json["currency"]
    assert_equal "EUR", json["user_currency"]
    # 5,000 USD (@sale_invoice) -> 4,600 EUR + 7,500 EUR (INV-EUR-001) = 12,100 EUR
    assert_equal 12100.0, json["kpis"]["total_sales_revenue"]

    # When requesting HTML dashboard, currency symbol matches EUR (€)
    get root_url
    assert_response :success
    assert_includes response.body, "EUR"
    assert_select "a[data-currency='all']", count: 0
  end

  test "dashboard converts all invoices to user selected currency without altering database invoice data" do
    # Create an invoice in PHP: 57,000 PHP (= 1,000 USD = 920 EUR)
    php_invoice = Invoice.create!(
      user: @user,
      recipient_company: @partner_company,
      invoice_number: "INV-PHP-001",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "paid",
      currency: "PHP",
      issue_date: Date.current,
      total: { "grand_total" => "57000.00" }
    )

    # User views dashboard in EUR
    sign_in @user
    get dashboards_analytics_data_url(time_frame: "this_month", currency: "EUR", format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "EUR", json["currency"]
    
    # Original invoices: @sale_invoice (5,000 USD -> 4,600 EUR) + php_invoice (57,000 PHP -> 920 EUR) = 5,520 EUR
    assert_equal 5520.0, json["kpis"]["total_sales_revenue"]

    # Invoices in database remain completely unchanged
    assert_equal "PHP", php_invoice.reload.currency
    assert_equal 57000.0, php_invoice.grand_total
    assert_equal "USD", @sale_invoice.reload.currency
    assert_equal 5000.0, @sale_invoice.grand_total
  end
end
