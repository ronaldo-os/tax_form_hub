require "test_helper"

class UrlSynchronizedFiltersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "url_sync_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Sync Test Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "invoices index handles and renders tab and query parameters" do
    # Default tab
    get invoices_path
    assert_response :success
    assert_select "#sales-invoices-tab.active"
    assert_select "#sales-invoices.active"

    # Specific tab in query parameter: purchase-invoices
    get invoices_path(tab: "purchase-invoices")
    assert_response :success
    assert_select "#purchase-invoices-tab.active"
    assert_select "#purchase-invoices.active"

    # Specific tab in query parameter: sent-quotes
    get invoices_path(tab: "sent-quotes")
    assert_response :success
    assert_select "#sent-quotes-tab.active"
    assert_select "#sent-quotes.active"

    # Specific tab and subtab: sales-invoices archived
    get invoices_path(tab: "sales-invoices", subtab: "archived")
    assert_response :success
    assert_select "#sales-invoices-tab.active"
    assert_select "#sales-archived-tab.active"
    assert_select "#sales-archived-pane.active"
    assert_select "#sales-active-tab:not(.active)"
    assert_select "#sales-active-pane:not(.active)"

    # Specific tab and subtab: purchase-invoices archived
    get invoices_path(tab: "purchase-invoices", subtab: "archived")
    assert_response :success
    assert_select "#purchase-invoices-tab.active"
    assert_select "#purchase-archived-tab.active"
    assert_select "#purchase-archived-pane.active"
    assert_select "#purchase-active-tab:not(.active)"
    assert_select "#purchase-active-pane:not(.active)"

    # Specific tab and subtab: sent-quotes archived
    get invoices_path(tab: "sent-quotes", subtab: "archived")
    assert_response :success
    assert_select "#sent-quotes-tab.active"
    assert_select "#sent-quotes-archived-tab.active"
    assert_select "#sent-quotes-archived-pane.active"

    # Specific tab and subtab: received-quotes archived
    get invoices_path(tab: "received-quotes", subtab: "archived")
    assert_response :success
    assert_select "#received-quotes-tab.active"
    assert_select "#received-quotes-archived-tab.active"
    assert_select "#received-quotes-archived-pane.active"

    # With search, status, and page query params preserved in request
    get invoices_path(tab: "sales-invoices", status: "paid", search: "October", page: 2, sort: "issue_date", dir: "asc")
    assert_response :success
    assert_select "#sales-table"
    assert_select "#sales-table th[data-data='total']"
    assert_select "#sales-table tfoot", 0
  end

  test "invoices datatable endpoint returns price total and respects sorting" do
    # Create two test invoices with known totals
    Invoice.create!(
      user: @user,
      invoice_number: "INV-SYNC-001",
      invoice_type: "sale",
      issue_date: Date.current,
      status: "draft",
      total: { "grand_total" => "1500.50" }
    )
    Invoice.create!(
      user: @user,
      invoice_number: "INV-SYNC-002",
      invoice_type: "sale",
      issue_date: Date.current - 1.day,
      status: "paid",
      total: { "grand_total" => "2500.25" }
    )

    # Server-side DataTables AJAX endpoint test with search and order
    get datatable_data_invoices_path, params: {
      draw: "1",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      order: {
        "0" => { "column" => "1", "dir" => "asc" }
      },
      search: { value: "SYNC" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("recordsTotal")
    assert json.key?("recordsFiltered")
    assert json.key?("data")
    assert json.key?("totalAmount")
    assert json.key?("formattedTotalAmount")

    # Sum of 1500.50 + 2500.25 = 4000.75
    assert_in_delta 4000.75, json["totalAmount"], 0.01
    assert_includes json["formattedTotalAmount"], "4,000.75"

    # Sorted ascending by invoice_number, so INV-SYNC-001 comes before INV-SYNC-002
    assert_equal 2, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-SYNC-001"
    assert_includes json["data"][1]["invoice_number"], "INV-SYNC-002"
  end

  test "invoices datatable endpoint searches by price total (e.g., 560)" do
    Invoice.create!(
      user: @user,
      invoice_number: "INV-PRICE-560",
      invoice_type: "sale",
      issue_date: Date.current,
      status: "draft",
      total: { "grand_total" => "560.00" }
    )
    Invoice.create!(
      user: @user,
      invoice_number: "INV-PRICE-1200",
      invoice_type: "sale",
      issue_date: Date.current,
      status: "draft",
      total: { "grand_total" => "1200.00" }
    )

    # Search for "560" in DataTable search returns only the 560 row
    get datatable_data_invoices_path, params: {
      draw: "1",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      search: { value: "560" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["recordsFiltered"]
    assert_equal 1, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-PRICE-560"
    assert_includes json["data"][0]["total"], "560.00"

    # Search with currency symbol e.g. "₱560"
    get datatable_data_invoices_path, params: {
      draw: "2",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      search: { value: "₱560" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["recordsFiltered"]
    assert_equal 1, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-PRICE-560"

    # Sort ascending by Total (column 3): 560 should come before 1200
    get datatable_data_invoices_path, params: {
      draw: "3",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      order: {
        "0" => { "column" => "3", "dir" => "asc" }
      },
      search: { value: "INV-PRICE" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-PRICE-560"
    assert_includes json["data"][1]["invoice_number"], "INV-PRICE-1200"

    # Sort descending by Total (column 3): 1200 should come before 560
    get datatable_data_invoices_path, params: {
      draw: "4",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      order: {
        "0" => { "column" => "3", "dir" => "desc" }
      },
      search: { value: "INV-PRICE" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-PRICE-1200"
    assert_includes json["data"][1]["invoice_number"], "INV-PRICE-560"

    # Sort using URL params sort: 'total', dir: 'asc'
    get datatable_data_invoices_path, params: {
      draw: "5",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      sort: "total",
      dir: "asc",
      search: { value: "INV-PRICE" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["data"].length
    assert_includes json["data"][0]["invoice_number"], "INV-PRICE-560"
    assert_includes json["data"][1]["invoice_number"], "INV-PRICE-1200"
  end

  test "invoices index highlights the correct status card based on query parameter" do
    # Default (no status param) activates the total card
    get invoices_path
    assert_response :success
    assert_select "#sales-invoices .card-filter[data-status=''].active"
    assert_select "#sales-invoices .card-filter[data-status='draft']:not(.active)"
    assert_select "#sales-invoices .card-filter[data-status='paid']:not(.active)"

    # With status=draft in URL query parameter
    get invoices_path(status: "draft")
    assert_response :success
    assert_select "#sales-invoices .card-filter[data-status='draft'].active"
    assert_select "#sales-invoices .card-filter[data-status='']:not(.active)"
    assert_select "#sales-invoices .card-filter[data-status='paid']:not(.active)"

    # With status=paid in URL query parameter on purchase-invoices tab
    get invoices_path(tab: "purchase-invoices", status: "paid")
    assert_response :success
    assert_select "#purchase-invoices .card-filter[data-status='paid'].active"
    assert_select "#purchase-invoices .card-filter[data-status='draft']:not(.active)"
  end

  test "invoices datatable endpoint responds to column search and pagination" do
    # Server-side DataTables AJAX endpoint test
    get datatable_data_invoices_path, params: {
      draw: "1",
      start: "0",
      length: "25",
      invoice_type: "sale",
      archived: "false",
      quote: "false",
      columns: {
        "6" => { search: { value: "^paid$", regex: "true" } }
      },
      search: { value: "October" }
    }, headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("recordsTotal")
    assert json.key?("recordsFiltered")
    assert json.key?("data")
  end

  test "subscriptions index handles tab and query parameters" do
    # Default tab: sales
    get subscriptions_path
    assert_response :success
    assert_select "#sales-tab.active"
    assert_select "#sales-pane.active"

    # Purchases tab
    get subscriptions_path(tab: "purchases")
    assert_response :success
    assert_select "#purchases-tab.active"
    assert_select "#purchases-pane.active"

    # With status, search, and page query params
    get subscriptions_path(tab: "sales", status: "finished", search: "Consulting", page: 1)
    assert_response :success
    assert_select "#salesActiveSubscriptionsTable"
  end

  test "tax_submissions index handles tab, status, and search query parameters" do
    get tax_submissions_path
    assert_response :success
    assert_select "#active-tab"
    assert_select "#taxSubmissionsTableActive"

    # Archived tab with query params
    get tax_submissions_path(tab: "archived", status: "Pending", search: "Form 2307")
    assert_response :success
    assert_select "#archived-tab"
    assert_select "#taxSubmissionsTableArchived"
  end

  test "tax_submissions home handles tab and query parameters" do
    get tax_submissions_home_path
    assert_response :success
    assert_select "#unarchived-tab"

    get tax_submissions_home_path(tab: "archived", status: "Processed", search: "October")
    assert_response :success
    assert_select "#archived-tab"
  end

  test "locations index renders DataTable and handles query parameters" do
    Location.create!(
      user: @user,
      location_type: "Warehouse",
      location_name: "Subic Hub",
      company_name: "Sync Test Corp",
      street: "Pier 1",
      city: "Subic",
      country: "Philippines"
    )

    get locations_path(type: "Warehouse", search: "Subic", page: 1)
    assert_response :success
    assert_select "#location-table"
    assert_select "tbody tr"
  end
end
