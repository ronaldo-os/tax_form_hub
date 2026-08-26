require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user_seller = User.create!(
      email: "seller_#{Time.now.to_f}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company_seller = Company.create!(name: "Acme Cloud Services", user: @user_seller)
    @user_seller.update!(company: @company_seller)

    @user_buyer = User.create!(
      email: "buyer_#{Time.now.to_f}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company_buyer = Company.create!(name: "Globex Corporation", user: @user_buyer)
    @user_buyer.update!(company: @company_buyer)

    @user_unrelated = User.create!(
      email: "unrelated_#{Time.now.to_f}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )

    # Create Sales subscription contract for seller
    @sales_subscription = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-001",
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

    # Duplicated Purchase subscription contract for buyer
    @purchase_subscription = Invoice.create!(
      user: @user_buyer,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "purchase",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-001",
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
  end

  test "redirects unauthenticated user to sign up" do
    get subscriptions_url
    assert_redirected_to new_user_registration_url
  end

  test "seller sees recurring subscription in Sales tab, not in Purchases tab" do
    sign_in @user_seller
    get subscriptions_url
    assert_response :success

    # Top tabs have sales active by default
    assert_select "#sales-tab.active"
    assert_select "#sales-pane.active"

    # In Sales pane, customer/recipient company is displayed
    assert_select "#sales-pane td", text: /Globex Corporation/
    assert_select "#sales-pane th", text: /Recipient/

    # Mid-cycle action available in Sales pane
    assert_select "#sales-pane button", text: /Add Mid-cycle Subscription/

    # In Purchases pane, no rows
    assert_select "#purchases-pane td", text: /Globex Corporation/, count: 0
  end

  test "buyer sees recurring subscription in Purchases tab, not in Sales tab" do
    sign_in @user_buyer
    get subscriptions_url, params: { tab: "purchases" }
    assert_response :success

    # Purchases tab is active
    assert_select "#purchases-tab.active"
    assert_select "#purchases-pane.active"

    # In Purchases pane, supplier company is displayed
    assert_select "#purchases-pane td", text: /Acme Cloud Services/
    assert_select "#purchases-pane th", text: /Supplier/

    # Mid-cycle action NOT available in purchases pane
    assert_select "#purchases-pane button", text: /Add Mid-cycle Subscription/, count: 0

    # In Sales pane, no subscriptions
    assert_select "#sales-pane td", text: /Acme Cloud Services/, count: 0
  end

  test "unrelated user sees no subscriptions (proper scoping)" do
    sign_in @user_unrelated
    get subscriptions_url
    assert_response :success
    assert_not_includes response.body, "Acme Cloud Services"
    assert_not_includes response.body, "Globex Corporation"
  end

  test "tab parameter sets active tab correctly" do
    sign_in @user_seller

    get subscriptions_url, params: { tab: "purchases" }
    assert_response :success
    assert_select "#purchases-tab.active"
    assert_select "#purchases-pane.active"

    get subscriptions_url, params: { tab: "sales" }
    assert_response :success
    assert_select "#sales-tab.active"
    assert_select "#sales-pane.active"

    # Invalid tab defaults to sales
    get subscriptions_url, params: { tab: "invalid_tab" }
    assert_response :success
    assert_select "#sales-tab.active"
    assert_select "#sales-pane.active"
  end

  test "seller can add mid-cycle subscription item" do
    sign_in @user_seller

    post add_mid_cycle_item_subscription_url(@sales_subscription), params: {
      item_name: "Additional Storage 50GB",
      item_type: "charge",
      quantity: "1",
      price: "50.00",
      effective_date: Date.current.to_s,
      charge_type: "recurring",
      proration: "full",
      parent_item_index: 0
    }

    assert_redirected_to subscription_url(@sales_subscription, item_index: 0)
    follow_redirect!
    assert_includes flash[:notice], "successfully"
  end

  test "buyer cannot add mid-cycle item to purchase subscription" do
    sign_in @user_buyer

    post add_mid_cycle_item_subscription_url(@purchase_subscription), params: {
      item_name: "Extra Service",
      item_type: "charge",
      quantity: "1",
      price: "50.00",
      effective_date: Date.current.to_s,
      charge_type: "recurring"
    }

    assert_redirected_to subscription_url(@purchase_subscription)
    assert_equal "Mid-cycle items can only be added to sales subscriptions.", flash[:alert]
  end

  test "cancelling a purchase subscription marks it cancelled without charging seller" do
    sign_in @user_buyer

    patch cancel_subscription_url(@purchase_subscription), params: {
      effective_date: Date.current.to_s,
      billing_option: "prorate",
      reason: "No longer needed"
    }

    assert_redirected_to subscription_url(@purchase_subscription)
    @purchase_subscription.reload
    assert @purchase_subscription.archived? || @purchase_subscription.subscription_cancelled?

    # Verify no immediate sub-invoice was generated by the buyer
    mid_invoices = @user_buyer.invoices.where(recurring_parent_invoice_id: @purchase_subscription.id)
    assert_equal 0, mid_invoices.count
  end
end
