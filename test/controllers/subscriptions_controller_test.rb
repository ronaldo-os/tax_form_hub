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

  test "viewing a subscription row displays Subscriptions header title instead of Tax Form Hub" do
    sign_in @user_seller

    get subscription_url(@sales_subscription)
    assert_response :success
    assert_select "h1.desktop-page-title", text: /Subscriptions/
    assert_select "h1.mobile-page-title", text: /Subscriptions/
  end

  test "subscriptions index page renders bulk action bar and row checkboxes for active subscriptions" do
    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    assert_select "#bulk_action_bar_salesActiveSubscriptionsTable"
    assert_select "form.bulk-subscriptions-form[action='#{bulk_action_subscriptions_path}']"
    assert_select "input.subscription-master-checkbox[data-table-id='salesActiveSubscriptionsTable']"
    assert_select "input.table-header-checkbox[data-table-id='salesActiveSubscriptionsTable']"
    assert_select "input.subscription-row-checkbox[value='#{@sales_subscription.id}']"
    assert_select "button[name='bulk_action'][value='cancel']"
  end

  test "subscriptions index page renders bulk action bar and row checkboxes for active purchase subscriptions" do
    sign_in @user_buyer

    get subscriptions_url, params: { tab: "purchases" }
    assert_response :success

    assert_select "#bulk_action_bar_purchasesActiveSubscriptionsTable"
    assert_select "input.subscription-row-checkbox[value='#{@purchase_subscription.id}']"
  end

  test "bulk cancel active sales subscriptions successfully cancels them" do
    sales_sub2 = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-002",
      currency: "USD",
      line_items_data: [
        {
          "description" => "Team Subscription Plan",
          "quantity" => "1",
          "price" => "100.00",
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
      total: { "grand_total" => "100.00" }
    )

    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [@sales_subscription.id, sales_sub2.id],
      bulk_action: "cancel",
      tab: "sales"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "Successfully cancelled 2 subscriptions.", flash[:notice]

    @sales_subscription.reload
    sales_sub2.reload

    assert @sales_subscription.archived? || @sales_subscription.subscription_cancelled?
    assert sales_sub2.archived? || sales_sub2.subscription_cancelled?
  end

  test "bulk cancel active purchase subscriptions successfully cancels them" do
    purchase_sub2 = Invoice.create!(
      user: @user_buyer,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "purchase",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-003",
      currency: "USD",
      line_items_data: [
        {
          "description" => "Developer Plan",
          "quantity" => "1",
          "price" => "50.00",
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
      total: { "grand_total" => "50.00" }
    )

    sign_in @user_buyer

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [@purchase_subscription.id, purchase_sub2.id],
      bulk_action: "cancel",
      tab: "purchases"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "purchases")
    assert_equal "Successfully cancelled 2 subscriptions.", flash[:notice]

    @purchase_subscription.reload
    purchase_sub2.reload

    assert @purchase_subscription.archived? || @purchase_subscription.subscription_cancelled?
    assert purchase_sub2.archived? || purchase_sub2.subscription_cancelled?
  end

  test "bulk action returns alert when no subscriptions are selected" do
    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [],
      bulk_action: "cancel",
      tab: "sales"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "No subscriptions selected.", flash[:alert]
  end

  test "bulk action enforces tenant isolation and ignores subscriptions of other users" do
    sign_in @user_unrelated

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [@sales_subscription.id],
      bulk_action: "cancel",
      tab: "sales"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "No authorized subscriptions found to perform this action.", flash[:alert]

    @sales_subscription.reload
    assert @sales_subscription.subscription_active?
  end

  test "bulk action handles invalid action type gracefully" do
    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [@sales_subscription.id],
      bulk_action: "invalid_action",
      tab: "sales"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "Invalid action.", flash[:alert]
  end

  test "unauthenticated bulk action redirects" do
    post bulk_action_subscriptions_url, params: {
      subscription_ids: [@sales_subscription.id],
      bulk_action: "cancel"
    }
    assert_response :redirect
  end

  test "seller can retry recurring invoicing successfully and clear previous error" do
    sign_in @user_seller

    @sales_subscription.update_column(
      :invoice_info,
      {
        "recurring_generation_error" => {
          "message" => "Previous transient failure",
          "failed_at" => 2.hours.ago.iso8601
        }
      }
    )

    post retry_invoicing_subscription_url(@sales_subscription)
    assert_redirected_to subscription_url(@sales_subscription)
    follow_redirect!
    assert_includes flash[:notice], "Successfully generated"

    @sales_subscription.reload
    assert_nil @sales_subscription.invoice_info["recurring_generation_error"]
    assert_equal 1, @sales_subscription.recurring_sub_invoices.count
  end

  test "retry recurring invoicing records error details if generation raises error" do
    sign_in @user_seller

    Invoice.class_eval do
      alias_method :orig_generate_subscription_invoices_test, :generate_subscription_invoices
      def generate_subscription_invoices(on_date = Date.current)
        raise StandardError, "Payment service unavailable"
      end
    end

    post retry_invoicing_subscription_url(@sales_subscription)
    assert_redirected_to subscription_url(@sales_subscription)
    assert_includes flash[:alert], "Payment service unavailable"

    @sales_subscription.reload
    err = @sales_subscription.invoice_info["recurring_generation_error"]
    assert_not_nil err
    assert_equal "Payment service unavailable", err["message"]
  ensure
    Invoice.class_eval do
      if method_defined?(:orig_generate_subscription_invoices_test)
        alias_method :generate_subscription_invoices, :orig_generate_subscription_invoices_test
        remove_method :orig_generate_subscription_invoices_test
      end
    end
  end

  test "unrelated user cannot retry invoicing on another user subscription" do
    sign_in @user_unrelated

    post retry_invoicing_subscription_url(@sales_subscription)
    assert_response :not_found
  end

  test "subscription show page displays error banner and retry button when recurring error exists" do
    sign_in @user_seller

    @sales_subscription.update_column(
      :invoice_info,
      {
        "recurring_generation_error" => {
          "message" => "Invoice generation failed due to invalid tax rate",
          "failed_at" => Time.current.iso8601
        }
      }
    )

    get subscription_url(@sales_subscription)
    assert_response :success
    assert_select ".alert.alert-danger", text: /Recurring Invoice Generation Failed/
    assert_select ".alert.alert-danger", text: /Invoice generation failed due to invalid tax rate/
    assert_select "form[action='#{retry_invoicing_subscription_path(@sales_subscription)}'] button", text: /Retry Generation/
  end
end
