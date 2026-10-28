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

  test "cancelling a subscription from index page redirects to redirect_to URL" do
    sign_in @user_seller

    patch cancel_subscription_url(@sales_subscription), params: {
      item_index: 0,
      effective_date: Date.current.to_s,
      billing_option: "none",
      reason: "Customer requested cancellation",
      redirect_to: subscriptions_url(tab: "sales")
    }

    assert_redirected_to subscriptions_url(tab: "sales")
    assert_equal "Subscription was successfully cancelled.", flash[:notice]

    @sales_subscription.reload
    assert @sales_subscription.archived? || @sales_subscription.subscription_cancelled?
  end

  test "subscriptions index page renders bulk action bar and row checkboxes for active sales price adjustments" do
    pa_sales = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-SALE-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Recurring Maintenance Fee",
          "description_edit" => "Recurring Maintenance Fee",
          "frequency" => "monthly",
          "amount" => "30.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Service Fee", "quantity" => "1", "price" => "100.00", "tax" => "0" }
      ],
      total: { "grand_total" => "130.00" }
    )

    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    assert_select "#bulk_action_bar_salesActivePriceAdjustmentsTable"
    assert_select "form.bulk-subscriptions-form#bulk_form_salesActivePriceAdjustmentsTable[action='#{bulk_action_subscriptions_path}']"
    assert_select "input.subscription-master-checkbox[data-table-id='salesActivePriceAdjustmentsTable']"
    assert_select "input.table-header-checkbox[data-table-id='salesActivePriceAdjustmentsTable']"
    assert_select "input.subscription-row-checkbox[data-table-id='salesActivePriceAdjustmentsTable'][value='#{pa_sales.id}']"
    assert_select "input.subscription-row-checkbox[data-table-id='salesActivePriceAdjustmentsTable'][data-allowed-actions='cancel']"
    assert_select "#bulk_action_bar_salesActivePriceAdjustmentsTable button[name='bulk_action'][value='cancel']"
  end

  test "subscriptions index page renders bulk action bar and row checkboxes for active purchase price adjustments" do
    pa_purchase = Invoice.create!(
      user: @user_buyer,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "purchase",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-PURCH-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Supplier Recurring Discount",
          "description_edit" => "Supplier Recurring Discount",
          "frequency" => "monthly",
          "amount" => "15.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Material Cost", "quantity" => "1", "price" => "150.00", "tax" => "0" }
      ],
      total: { "grand_total" => "135.00" }
    )

    sign_in @user_buyer

    get subscriptions_url, params: { tab: "purchases" }
    assert_response :success

    assert_select "#bulk_action_bar_purchasesActivePriceAdjustmentsTable"
    assert_select "form.bulk-subscriptions-form#bulk_form_purchasesActivePriceAdjustmentsTable[action='#{bulk_action_subscriptions_path}']"
    assert_select "input.subscription-master-checkbox[data-table-id='purchasesActivePriceAdjustmentsTable']"
    assert_select "input.table-header-checkbox[data-table-id='purchasesActivePriceAdjustmentsTable']"
    assert_select "input.subscription-row-checkbox[data-table-id='purchasesActivePriceAdjustmentsTable'][value='#{pa_purchase.id}']"
    assert_select "input.subscription-row-checkbox[data-table-id='purchasesActivePriceAdjustmentsTable'][data-allowed-actions='cancel']"
    assert_select "#bulk_action_bar_purchasesActivePriceAdjustmentsTable button[name='bulk_action'][value='cancel']"
  end

  test "bulk cancel active sales price adjustments successfully cancels them" do
    pa1 = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-SALE-101",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Adjustment 1",
          "frequency" => "monthly",
          "amount" => "20.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Item 1", "quantity" => "1", "price" => "100.00", "tax" => "0" }
      ],
      total: { "grand_total" => "120.00" }
    )

    pa2 = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-SALE-102",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Adjustment 2",
          "frequency" => "monthly",
          "amount" => "30.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Item 2", "quantity" => "1", "price" => "200.00", "tax" => "0" }
      ],
      total: { "grand_total" => "230.00" }
    )

    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [pa1.id, pa2.id],
      bulk_action: "cancel",
      tab: "sales"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "Successfully cancelled 2 price adjustments.", flash[:notice]

    pa1.reload
    pa2.reload

    assert pa1.archived? || pa1.subscription_cancelled?
    assert pa2.archived? || pa2.subscription_cancelled?
    assert_not pa1.subscription_active?
    assert_not pa2.subscription_active?
  end

  test "bulk cancel active purchase price adjustments successfully cancels them" do
    pa_purch1 = Invoice.create!(
      user: @user_buyer,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "purchase",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-PURCH-101",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Purch Adj 1",
          "frequency" => "monthly",
          "amount" => "10.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Purch Item 1", "quantity" => "1", "price" => "50.00", "tax" => "0" }
      ],
      total: { "grand_total" => "40.00" }
    )

    pa_purch2 = Invoice.create!(
      user: @user_buyer,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "purchase",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-PURCH-102",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Purch Adj 2",
          "frequency" => "monthly",
          "amount" => "15.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Purch Item 2", "quantity" => "1", "price" => "60.00", "tax" => "0" }
      ],
      total: { "grand_total" => "45.00" }
    )

    sign_in @user_buyer

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [pa_purch1.id, pa_purch2.id],
      bulk_action: "cancel",
      tab: "purchases"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "purchases")
    assert_equal "Successfully cancelled 2 price adjustments.", flash[:notice]

    pa_purch1.reload
    pa_purch2.reload

    assert pa_purch1.archived? || pa_purch1.subscription_cancelled?
    assert pa_purch2.archived? || pa_purch2.subscription_cancelled?
    assert_not pa_purch1.subscription_active?
    assert_not pa_purch2.subscription_active?
  end

  test "subscriptions and price adjustments render data-allowed-actions reflecting active status" do
    cancelled_sub = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-CANCELLED",
      currency: "USD",
      archived: true,
      line_items_data: [
        {
          "description" => "Cancelled Plan",
          "quantity" => "1",
          "price" => "100.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "billing_cycle" => "monthly",
              "start_date" => (Date.current - 2.months).to_s,
              "end_date" => (Date.current + 10.months).to_s
            },
            "cancelled" => true
          }
        }
      ],
      total: { "grand_total" => "100.00" }
    )

    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    # Active subscription row checkbox has cancel allowed
    assert_select "input.subscription-row-checkbox[value='#{@sales_subscription.id}'][data-allowed-actions='cancel']"

    # Helper directly verifies active vs cancelled
    active_wrapper = SubscriptionItemWrapper.new(@sales_subscription, @sales_subscription.line_items_data[0], 0)
    cancelled_wrapper = SubscriptionItemWrapper.new(cancelled_sub, cancelled_sub.line_items_data[0], 0)

    helper = Object.new.extend(SubscriptionsHelper)
    assert_equal ["cancel"], helper.allowed_subscription_bulk_actions(active_wrapper)
    assert_equal [], helper.allowed_subscription_bulk_actions(cancelled_wrapper)
    assert_equal ["cancel"], helper.allowed_subscription_bulk_actions(@sales_subscription)
    assert_equal [], helper.allowed_subscription_bulk_actions(cancelled_sub)
  end

  test "subscriptions index page renders single Create Document dropdown containing invoice, quote, and credit note options" do
    sign_in @user_seller
    get subscriptions_url
    assert_response :success

    assert_select "button#createDocumentDropdown", text: /Create Document/
    assert_select "ul.dropdown-menu[aria-labelledby='createDocumentDropdown']" do
      assert_select "a[href*='/invoices/new']", text: /Create Invoice/
      assert_select "a[href*='category=quote']", text: /Create Quote/
      assert_select "a[href*='category=credit_note']", text: /Create Credit Note/
    end
  end

  test "subscriptions index page renders multiple recurring price adjustments from one invoice as separate rows" do
    pa_multiple = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-MULTI-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Cloud Storage Support",
          "description_edit" => "Cloud Storage Support",
          "frequency" => "monthly",
          "amount" => "25.00",
          "unit" => "USD",
          "type" => "charge",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        },
        {
          "description" => "Priority SLA Discount",
          "description_edit" => "Priority SLA Discount",
          "frequency" => "annually",
          "amount" => "10.00",
          "unit" => "%",
          "type" => "discount",
          "charge_start_date" => (Date.current - 2.months).to_s,
          "charge_end_date" => (Date.current + 10.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Base Enterprise Package", "quantity" => "1", "price" => "500.00", "tax" => "0" }
      ],
      total: { "grand_total" => "475.00" }
    )

    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    # Verify both rows are rendered under salesActivePriceAdjustmentsTable
    assert_select "#salesActivePriceAdjustmentsTable tbody tr[data-subscription-id='#{pa_multiple.id}']", count: 2
    assert_select "#salesActivePriceAdjustmentsTable tbody tr[data-subscription-id='#{pa_multiple.id}'][data-item-index='0']" do
      assert_select "td", text: /Cloud Storage Support/
      assert_select "td", text: /Monthly/
      assert_select "td", text: /25\.00/
      assert_select "a[href*='item_index=0']"
      assert_select "input.subscription-row-checkbox[data-item-index='0']"
    end

    assert_select "#salesActivePriceAdjustmentsTable tbody tr[data-subscription-id='#{pa_multiple.id}'][data-item-index='1']" do
      assert_select "td", text: /Priority SLA Discount/
      assert_select "td", text: /Annual/
      assert_select "td", text: /10\.0%/
      assert_select "a[href*='item_index=1']"
      assert_select "input.subscription-row-checkbox[data-item-index='1']"
    end
  end

  test "subscriptions index page separates active and finished recurring price adjustments from the same invoice" do
    pa_mixed = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-MIXED-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Still Active Recurring Adjustment",
          "frequency" => "monthly",
          "amount" => "40.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 6.months).to_s
        },
        {
          "description" => "Already Finished Adjustment",
          "frequency" => "monthly",
          "amount" => "10.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 12.months).to_s,
          "charge_end_date" => (Date.current - 1.month).to_s
        }
      ],
      line_items_data: [
        { "description" => "Core Service", "quantity" => "1", "price" => "200.00", "tax" => "0" }
      ],
      total: { "grand_total" => "230.00" }
    )

    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    # Active table has the active adjustment
    assert_select "#salesActivePriceAdjustmentsTable tbody tr[data-subscription-id='#{pa_mixed.id}'][data-item-index='0']" do
      assert_select "td", text: /Still Active Recurring Adjustment/
    end

    # Finished table has the finished adjustment
    assert_select "#salesFinishedPriceAdjustmentsTable tbody tr[data-subscription-id='#{pa_mixed.id}'][data-item-index='1']" do
      assert_select "td", text: /Already Finished Adjustment/
    end
  end

  test "price adjustments show page displays specific adjustment details when item_index is specified" do
    pa = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-SHOW-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "First Fee",
          "frequency" => "monthly",
          "amount" => "35.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 5.months).to_s
        },
        {
          "description" => "Second Discount",
          "frequency" => "yearly",
          "amount" => "50.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 2.months).to_s,
          "charge_end_date" => (Date.current + 10.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Platform License", "quantity" => "1", "price" => "300.00", "tax" => "0" }
      ],
      total: { "grand_total" => "285.00" }
    )

    sign_in @user_seller

    get price_adjustment_url(pa, item_index: 1)
    assert_response :success
    assert_select ".card-body", text: /Second Discount/
    assert_select ".card-body", text: /Annual/
  end

  test "cancelling a single price adjustment from an invoice with multiple adjustments only cancels that specific adjustment" do
    pa = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-CANCEL-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Cancel This Fee",
          "frequency" => "monthly",
          "amount" => "20.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        },
        {
          "description" => "Keep This Fee Active",
          "frequency" => "monthly",
          "amount" => "40.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Standard Membership", "quantity" => "1", "price" => "100.00", "tax" => "0" }
      ],
      total: { "grand_total" => "160.00" }
    )

    sign_in @user_seller

    patch cancel_subscription_url(pa), params: {
      item_type: "Price Adjustment",
      item_index: 0,
      effective_date: Date.current.to_s,
      billing_option: "none",
      reason: "No longer needed",
      redirect_to: subscriptions_url(tab: "sales")
    }

    assert_redirected_to subscriptions_url(tab: "sales")
    assert_equal "Price adjustment was successfully cancelled.", flash[:notice]

    pa.reload
    assert_not pa.archived?, "Invoice should not be archived while other active adjustments exist"
    assert pa.price_adjustments[0]["cancelled"], "Targeted adjustment should be cancelled"
    assert_not pa.price_adjustments[1]["cancelled"], "Untargeted adjustment should remain active"
  end

  test "subscriptions index page renders bulk cancel subscription modal with proper form elements" do
    sign_in @user_seller

    get subscriptions_url
    assert_response :success

    assert_select "#cancelSubscriptionModal-bulk-salesActiveSubscriptionsTable"
    assert_select "form#bulk_cancel_form_salesActiveSubscriptionsTable[action='#{bulk_action_subscriptions_path}']"
    assert_select "#bulkEffectiveDate-salesActiveSubscriptionsTable"
    assert_select "#bulkBillingNone-salesActiveSubscriptionsTable"
    assert_select "#bulkBillingProrate-salesActiveSubscriptionsTable"
    assert_select "#bulkBillingFull-salesActiveSubscriptionsTable"
    assert_select "#bulkCancellationReason-salesActiveSubscriptionsTable"
  end

  test "bulk cancel active sales subscriptions with prorate option generates final invoices and records cancellation" do
    sub1 = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-PRORATE-001",
      currency: "USD",
      line_items_data: [
        {
          "description" => "Plan 1",
          "quantity" => "1",
          "price" => "100.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "billing_cycle" => "monthly",
              "start_date" => (Date.current - 10.days).to_s,
              "end_date" => (Date.current + 11.months).to_s
            }
          }
        }
      ],
      total: { "grand_total" => "100.00" }
    )

    sales_sub2 = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "SUB-PRORATE-002",
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
              "start_date" => (Date.current - 10.days).to_s,
              "end_date" => (Date.current + 11.months).to_s
            }
          }
        }
      ],
      total: { "grand_total" => "100.00" }
    )

    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: [sub1.id, sales_sub2.id],
      bulk_action: "cancel",
      tab: "sales",
      billing_option: "prorate",
      effective_date: Date.current.to_s,
      reason: "Bulk cancellation test with prorate"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "Successfully cancelled 2 subscriptions.", flash[:notice]

    sub1.reload
    sales_sub2.reload

    assert sub1.archived? || sub1.subscription_cancelled?
    assert sales_sub2.archived? || sales_sub2.subscription_cancelled?

    # Verify cancellation line item recorded the reason and billing option
    c1 = sub1.cancellation_line_item
    assert_not_nil c1
    assert_equal "prorate", c1.dig("optional_fields", "billing_option")
    assert_includes c1["description"], "Bulk cancellation test with prorate"

    # Verify final immediate sub-invoices were created
    mid_invoices = @user_seller.invoices.where(recurring_parent_invoice_id: [sub1.id, sales_sub2.id])
    assert_operator mid_invoices.count, :>=, 1
  end

  test "bulk cancel active sales price adjustments with item index format cancels only targeted adjustments" do
    pa = Invoice.create!(
      user: @user_seller,
      sale_from: @company_seller,
      recipient_company: @company_buyer,
      invoice_type: "sale",
      invoice_category: "standard",
      issue_date: Date.current,
      invoice_number: "PA-BULK-TARGET-001",
      currency: "USD",
      price_adjustments: [
        {
          "description" => "Targeted PA",
          "frequency" => "monthly",
          "amount" => "25.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        },
        {
          "description" => "Retained PA",
          "frequency" => "monthly",
          "amount" => "35.00",
          "unit" => "USD",
          "charge_start_date" => (Date.current - 1.month).to_s,
          "charge_end_date" => (Date.current + 11.months).to_s
        }
      ],
      line_items_data: [
        { "description" => "Standard Item", "quantity" => "1", "price" => "100.00", "tax" => "0" }
      ],
      total: { "grand_total" => "160.00" }
    )

    sign_in @user_seller

    post bulk_action_subscriptions_url, params: {
      subscription_ids: ["#{pa.id}:0"],
      bulk_action: "cancel",
      tab: "sales",
      item_type: "Price Adjustment",
      billing_option: "none",
      effective_date: Date.current.to_s,
      reason: "Bulk cancelled price adjustment 0"
    }

    assert_response :redirect
    assert_redirected_to subscriptions_path(tab: "sales")
    assert_equal "Successfully cancelled 1 price adjustment.", flash[:notice]

    pa.reload
    assert_not pa.archived?, "Should not archive invoice while other price adjustment is active"
    assert pa.price_adjustments[0]["cancelled"], "Index 0 price adjustment should be cancelled"
    assert_not pa.price_adjustments[1]["cancelled"], "Index 1 price adjustment should remain active"
  end
end
