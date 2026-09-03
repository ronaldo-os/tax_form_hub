require "test_helper"

class BackNavigationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "nav_test_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Test Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "invoices show back button uses stored referrer when present" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft"
    )

    referrer_url = invoices_url(tab: "sent-quotes")
    get invoice_url(invoice), headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "invoices show back button falls back to invoices_path when referrer is absent" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft"
    )

    get invoice_url(invoice)
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", invoices_path
  end

  test "invoices edit back button uses stored referrer when present" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft"
    )

    referrer_url = invoice_url(invoice)
    get edit_invoice_url(invoice), headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "companies index back button uses stored referrer when present" do
    referrer_url = root_url
    get companies_url, headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "subscriptions_show_back_button_uses_stored_referrer_when_present" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "sent",
      currency: "USD",
      line_items_data: [
        {
          "description" => "Enterprise SaaS Plan",
          "quantity" => "1",
          "price" => "250.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "billing_cycle" => "monthly",
              "start_date" => (Date.current - 1.month).to_s,
              "end_date" => (Date.current + 11.months).to_s
            }
          }
        }
      ],
      total: { "grand_total" => "250.00" }
    )

    referrer_url = subscriptions_url(tab: "sales")
    get subscription_url(invoice), headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "tax submissions index back button uses stored referrer when present" do
    referrer_url = tax_submissions_home_url
    get tax_submissions_url, headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "tax submissions home back button uses stored referrer when present" do
    referrer_url = root_url
    get tax_submissions_home_url, headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end

  test "self-referencing referrer is ignored to prevent loops" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft"
    )

    initial_referrer = invoices_url(tab: "sales-invoices")
    get invoice_url(invoice), headers: { "HTTP_REFERER" => initial_referrer }
    assert_response :success
    assert_equal initial_referrer, session[:invoices_back_url]

    # Now make request where referrer is the same show url
    get invoice_url(invoice), headers: { "HTTP_REFERER" => invoice_url(invoice) }
    assert_response :success
    assert_equal initial_referrer, session[:invoices_back_url], "Self-referencing referrer should not overwrite previous back URL"
  end

  test "price adjustments show back button uses stored referrer when present" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "sent",
      currency: "PHP",
      price_adjustments: [
        {
          "description" => "Annual Inflation Adj",
          "frequency" => "annually",
          "amount" => "50",
          "unit" => "PHP",
          "charge_start_date" => "2026-06-01",
          "charge_end_date" => "2026-12-31"
        }
      ]
    )

    referrer_url = subscriptions_url(tab: "sales")
    get price_adjustment_url(invoice), headers: { "HTTP_REFERER" => referrer_url }
    assert_response :success
    assert_select "a[data-behavior='back-button'][href=?]", referrer_url
  end
end
