require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "test_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    sign_in @user
  end

  test "should create invoice with save for future flags" do
    post invoices_url, params: {
      invoice: {
        invoice_type: "sale",
        invoice_category: "standard",
        save_payment_terms_for_future: "1",
        save_notes_for_future: "1",
        save_footer_notes_for_future: "1",
        recipient_note: "Test note"
      }
    }

    assert_response :redirect
    invoice = Invoice.order(created_at: :desc).first
    assert_not_nil invoice
    assert invoice.save_payment_terms_for_future, "save_payment_terms_for_future should be true"
    assert invoice.save_notes_for_future, "save_notes_for_future should be true"
    assert invoice.save_footer_notes_for_future, "save_footer_notes_for_future should be true"
  end

  test "datatable returns centered image attachment html" do
    # Create an invoice
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "sent"
    )
    
    # Attach a fake image
    file = fixture_file_upload(Rails.root.join('test', 'fixtures', 'files', 'test_image.png'), 'image/png')
    invoice.attachments.attach(file)

    get datatable_data_invoices_url, params: { invoice_type: "sale", format: :json }
    
    assert_response :success
    data = JSON.parse(response.body)["data"]
    
    # Assert there is data
    assert_not_empty data
    
    # Check if the attachments column contains the new centered div HTML for images
    attachment_html = data.first["attachments"]
    assert_match /d-flex flex-column align-items-center justify-content-center/, attachment_html
    assert_match /text-truncate/, attachment_html
    assert_match /test_image.png/, attachment_html
    assert_match /object-fit: contain/, attachment_html
    assert_match /max-height: 70vh/, attachment_html
  end

  test "datatable filters records by status column parameter" do
    Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", status: "draft")
    Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", status: "paid")

    get datatable_data_invoices_url, params: {
      invoice_type: "sale",
      columns: {
        "5" => { "data" => "status", "search" => { "value" => "draft" } }
      },
      format: :json
    }

    assert_response :success
    json = JSON.parse(response.body)
    data = json["data"]

    assert_equal 1, data.length
    assert_equal "Draft", data.first["status"]
  end

  test "datatable sorts by columns correctly" do
    comp_a = Company.create!(name: "AAA Customer", user: @user)
    comp_b = Company.create!(name: "ZZZ Customer", user: @user)

    Invoice.create!(user: @user, recipient_company: comp_a, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-001", issue_date: Date.current - 10.days, total: { "grand_total" => "100.00" }, status: "draft")
    Invoice.create!(user: @user, recipient_company: comp_b, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-002", issue_date: Date.current - 1.day, total: { "grand_total" => "500.00" }, status: "paid")

    [0, 1, 2, 3, 5].each do |col_idx|
      ["asc", "desc"].each do |dir|
        get datatable_data_invoices_url, params: {
          invoice_type: "sale",
          order: { "0" => { "column" => col_idx.to_s, "dir" => dir } },
          format: :json
        }
        assert_response :success
        json = JSON.parse(response.body)
        assert json.key?("data")
      end
    end
  end

  test "generated subscription sub-invoices do not have attachments" do
    parent_invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "2026-00001-001",
      line_items_data: [
        {
          "description" => "Monthly SaaS Subscription",
          "quantity" => "1",
          "price" => "100.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "subscription_start_date" => (Date.current - 1.month - 1.day).to_s,
              "subscription_end_date" => (Date.current + 1.year).to_s,
              "subscription_billing_cycle" => "monthly"
            }
          }
        }
      ]
    )
    file = fixture_file_upload(Rails.root.join('test', 'fixtures', 'files', 'test_image.png'), 'image/png')
    parent_invoice.attachments.attach(file)

    assert parent_invoice.attachments.attached?, "Parent invoice should have attachment"

    sub_invoice = parent_invoice.generate_subscription_invoice(Date.current)
    assert sub_invoice.recurring_sub_invoice?, "Generated invoice should be a recurring sub-invoice"
    assert_not sub_invoice.attachments.attached?, "Generated recurring sub-invoice should NOT have attachments"
  end

  test "new action displays Create New Quote title when category is quote" do
    get new_invoice_url, params: { category: "quote" }
    assert_response :success
    assert_includes response.body, "Create New Quote"
  end

  test "new action displays Create New Credit Note title when category is credit_note" do
    get new_invoice_url, params: { category: "credit_note" }
    assert_response :success
    assert_includes response.body, "Create New Credit Note"
  end

  test "new action displays Create New Invoice title by default" do
    get new_invoice_url
    assert_response :success
    assert_includes response.body, "Create New Invoice"
  end

  test "generated recurring price adjustments format description consistently with line items" do
    parent_invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "2026-00001-002",
      line_items_data: [
        {
          "description" => "Core Platform",
          "quantity" => "1",
          "price" => "500.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "subscription_start_date" => (Date.current - 1.month - 1.day).to_s,
              "subscription_end_date" => (Date.current + 1.year).to_s,
              "subscription_billing_cycle" => "monthly"
            }
          }
        }
      ],
      price_adjustments: [
        {
          "type" => "charge",
          "description" => "Support Fee",
          "description_edit" => "Support Fee",
          "amount" => "50.00",
          "unit" => "USD",
          "frequency" => "monthly",
          "charge_start_date" => (Date.current - 1.month - 1.day).to_s,
          "charge_end_date" => (Date.current + 1.year).to_s
        }
      ]
    )

    sub_invoice = parent_invoice.generate_subscription_invoice(Date.current)
    adj = sub_invoice.price_adjustments.first

    assert_includes adj["description"], "Support Fee"
    assert_includes adj["description"], "Monthly Payment for Invoice #2026-00001-002"
    assert_equal adj["description"], adj["description_edit"]
    assert adj["overall_end_date"].present?
  end

  test "GenerateRecurringInvoicesJob generates all due sub-invoices when running with future on_date" do
    parent_invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "2026-00001-003",
      line_items_data: [
        {
          "description" => "Annual Plan Monthly Billing",
          "quantity" => "1",
          "price" => "100.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "subscription_start_date" => Date.current.to_s,
              "subscription_end_date" => (Date.current + 1.year).to_s,
              "subscription_billing_cycle" => "monthly"
            }
          }
        }
      ]
    )

    results = GenerateRecurringInvoicesJob.perform_now(on_date: 12.months.from_now.to_date)
    assert_equal 1, results[:successful]
    assert_equal 11, results[:invoices_generated]
    assert_equal 11, parent_invoice.reload.recurring_sub_invoices.count

    sub_invoices = parent_invoice.recurring_sub_invoices.order(:recurring_sequence_number)
    first_sub = sub_invoices.first
    final_sub = sub_invoices.last

    first_item = first_sub.line_items_data.first
    assert_includes first_item["description"], "(02/12)"
    first_sub_opt = first_item["optional_fields"]["subscription"]
    assert_equal (Date.current + 1.month).to_s, first_sub_opt["subscription_start_date"]
    assert_equal (Date.current + 2.months).to_s, first_sub_opt["subscription_end_date"]
    assert_equal (Date.current + 1.year).to_s, first_sub_opt["overall_end_date"]

    final_item = final_sub.line_items_data.first
    assert_includes final_item["description"], "(12/12)"
    final_sub_opt = final_item["optional_fields"]["subscription"]
    assert_equal (Date.current + 11.months).to_s, final_sub_opt["subscription_start_date"]
    assert_equal (Date.current + 1.year).to_s, final_sub_opt["subscription_end_date"]
    assert_equal (Date.current + 1.year).to_s, final_sub_opt["overall_end_date"]
  end

  test "mid-cycle subscription items format correct sequence count through to final invoice" do
    start_d = Date.new(2026, 1, 1)
    end_d = Date.new(2027, 1, 1)
    mid_start_d = Date.new(2026, 3, 1)

    parent_invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "2026-00001-004",
      line_items_data: [
        {
          "description" => "Primary Plan",
          "quantity" => "1",
          "price" => "100.00",
          "tax" => "0",
          "optional_fields" => {
            "subscription" => {
              "subscription_start_date" => start_d.to_s,
              "subscription_end_date" => end_d.to_s,
              "subscription_billing_cycle" => "monthly"
            }
          }
        },
        {
          "description" => "Add-on Seat",
          "quantity" => "1",
          "price" => "20.00",
          "tax" => "0",
          "optional_fields" => {
            "hidden_on_parent" => true,
            "subscription" => {
              "subscription_start_date" => mid_start_d.to_s,
              "subscription_end_date" => end_d.to_s,
              "subscription_billing_cycle" => "monthly"
            }
          }
        }
      ]
    )

    results = GenerateRecurringInvoicesJob.perform_now(on_date: Date.new(2027, 1, 1))
    assert_equal 11, results[:invoices_generated]

    sub_invoices = parent_invoice.reload.recurring_sub_invoices.order(:recurring_sequence_number)

    # Sub-invoice 1 (Feb 2026): Add-on Seat not included yet
    sub1_items = sub_invoices[0].line_items_data
    assert_equal 1, sub1_items.size
    assert_includes sub1_items[0]["description"], "(02/12)"

    # Sub-invoice 2 (Mar 2026): Add-on Seat first payment (01/10)
    sub2_items = sub_invoices[1].line_items_data
    assert_equal 2, sub2_items.size
    assert_includes sub2_items[0]["description"], "(03/12)"
    assert_includes sub2_items[1]["description"], "(01/10)"

    # Sub-invoice 11 (Dec 2026, final invoice): Primary is (12/12), Add-on is (10/10)
    final_items = sub_invoices[10].line_items_data
    assert_equal 2, final_items.size
    assert_includes final_items[0]["description"], "(12/12)"
    assert_includes final_items[1]["description"], "(10/10)"
    assert_equal "2027-01-01", final_items[1]["optional_fields"]["subscription"]["overall_end_date"]
    assert_equal "2027-01-01", final_items[1]["optional_fields"]["subscription"]["subscription_end_date"]
  end

  test "mark_as_paid marks invoice as paid and redirects to index" do
    company = Company.create!(name: "Client Inc", user: @user)
    invoice = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-PAID-001",
      status: "sent"
    )

    patch mark_as_paid_invoice_url(invoice, tab: "sales-invoices")
    assert_redirected_to invoices_url(tab: "sales-invoices")
    assert_equal "paid", invoice.reload.status
  end

  test "invoices index loads successfully with all server_side_table partials" do
    get invoices_url
    assert_response :success
    assert_includes response.body, 'data-server-side="true"'
    assert_includes response.body, 'id="sales-table"'
    assert_includes response.body, 'id="purchases-table"'
  end

  test "datatable preloads credit note existence without errors" do
    Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-PRELOAD-001",
      status: "sent"
    )

    get datatable_data_invoices_url, params: { invoice_type: "sale", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
  end

  test "receiver cannot mark purchase invoice as paid" do
    company = Company.create!(name: "Supplier Inc", user: @user)
    purchase_invoice = Invoice.create!(
      user: @user,
      sale_from: company,
      invoice_type: "purchase",
      invoice_category: "standard",
      invoice_number: "PURCH-PAID-001",
      status: "approved"
    )

    patch mark_as_paid_invoice_url(purchase_invoice, tab: "purchase-invoices")
    assert_redirected_to invoices_url(tab: "purchase-invoices")
    assert_equal "approved", purchase_invoice.reload.status
    assert_equal "Receiver of invoice cannot mark invoice as paid. Only the issuer can mark it as paid.", flash[:alert]
  end

  test "datatable does not include Mark as Paid for purchase invoices" do
    company = Company.create!(name: "Supplier Inc", user: @user)
    Invoice.create!(
      user: @user,
      sale_from: company,
      invoice_type: "purchase",
      invoice_category: "standard",
      invoice_number: "PURCH-DT-001",
      status: "approved"
    )

    get datatable_data_invoices_url, params: { invoice_type: "purchase", tab: "purchase-invoices", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
    assert_no_match /Mark as Paid/, data.first["actions"]
  end

  test "datatable includes Mark as Paid for sale invoices" do
    company = Company.create!(name: "Client Inc", user: @user)
    Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "SALE-DT-001",
      status: "approved"
    )

    get datatable_data_invoices_url, params: { invoice_type: "sale", tab: "sales-invoices", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
    assert_match /Mark as Paid/, data.first["actions"]
  end

  test "show action redirects to counterpart invoice if user accesses counterparty invoice ID" do
    other_user = User.create!(email: "seller_#{Time.now.to_i}_#{rand(1000)}@example.com", password: "Password123!@#Secure")
    seller_comp = Company.create!(name: "Seller Corp #{rand(1000)}", user: other_user)
    buyer_comp = Company.create!(name: "Buyer Corp #{rand(1000)}", user: @user)

    seller_invoice = Invoice.create!(
      user: other_user,
      invoice_number: "INV-CP-999",
      invoice_type: "sale",
      invoice_category: "standard",
      recipient_company: buyer_comp
    )

    buyer_invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-CP-999",
      invoice_type: "purchase",
      invoice_category: "standard",
      sale_from: seller_comp
    )

    # @user accesses seller_invoice.id -> should redirect to buyer_invoice
    get invoice_url(seller_invoice)
    assert_response :see_other
    assert_redirected_to invoice_url(buyer_invoice)
  end

  test "show action gracefully redirects when invoice is completely missing or unauthorized" do
    get invoice_url(id: 999999)
    assert_redirected_to invoices_url
    assert_equal "Invoice not found or access denied.", flash[:alert]
  end

  test "datatable formats invoice number link with preview-invoice class and data-id" do
    company = Company.create!(name: "Preview Test Inc", user: @user)
    invoice = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "SALE-PREVIEW-001",
      status: "draft"
    )

    get datatable_data_invoices_url, params: { invoice_type: "sale", tab: "sales-invoices", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
    invoice_row = data.find { |row| row["DT_RowId"] == "invoice_#{invoice.id}" }
    assert_match /preview-invoice/, invoice_row["invoice_number"]
    assert_match /preview-invoice-mobile/, invoice_row["invoice_number"]
    assert_match /data-id="#{invoice.id}"/, invoice_row["invoice_number"]
    assert_match /SALE-PREVIEW-001/, invoice_row["invoice_number"]
    assert_match %r{href="/invoices/#{invoice.id}\?tab=sales-invoices"}, invoice_row["invoice_number"]
  end

  test "export_csv returns 200 with text/csv, attachment disposition, and financial reporting headers" do
    company = Company.create!(name: "Acme Financial Services", tax_id_number: "987-654-321-000", user: @user)
    invoice = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-CSV-001",
      issue_date: Date.new(2026, 9, 1),
      currency: "PHP",
      status: "paid",
      total: { "subtotal" => "10000.00", "tax" => "1200.00", "discount" => "0.00", "grand_total" => "11200.00" },
      recipient_note: "Bookkeeping test note"
    )

    get export_csv_invoices_url, params: { invoice_type: "sale", tab: "sales-invoices" }
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
    assert_match /attachment; filename="invoices_sales_invoices_active_.*\.csv"/, response.headers["Content-Disposition"]
    assert_equal "1", response.headers["X-Total-Count"]

    body = response.body
    # Verify UTF-8 BOM
    assert body.start_with?("\uFEFF")

    # Verify financial reporting headers
    assert_includes body, "Invoice #"
    assert_includes body, "Transaction Type"
    assert_includes body, "Subtotal (Excl. Tax)"
    assert_includes body, "Tax Amount"
    assert_includes body, "Grand Total"
    assert_includes body, "Customer Name"
    assert_includes body, "Customer TIN"

    # Verify record data values
    assert_includes body, "INV-CSV-001"
    assert_includes body, "Acme Financial Services"
    assert_includes body, "987-654-321-000"
    assert_includes body, "10000.00"
    assert_includes body, "1200.00"
    assert_includes body, "11200.00"
    assert_includes body, "Paid"
    assert_includes body, "Bookkeeping test note"

    # Also test format: :csv via index
    get invoices_url(format: :csv, invoice_type: "sale", tab: "sales-invoices")
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.content_type
  end

  test "export_csv filters records by invoice_type, archived, quote, status, and search" do
    company = Company.create!(name: "Filter Target Corp", user: @user)
    inv_paid = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-PAID-100",
      status: "paid"
    )
    inv_draft = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-DRAFT-200",
      status: "draft"
    )
    inv_quote = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "quote",
      invoice_number: "Q-QUOTE-300",
      status: "sent"
    )
    inv_archived = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-ARCH-400",
      status: "paid",
      archived: true
    )

    # Filter by status: paid (active standard sale)
    get export_csv_invoices_url, params: { invoice_type: "sale", status: "paid", archived: "false", quote: "false" }
    assert_response :success
    assert_includes response.body, "INV-PAID-100"
    assert_not_includes response.body, "INV-DRAFT-200"
    assert_not_includes response.body, "Q-QUOTE-300"
    assert_not_includes response.body, "INV-ARCH-400"

    # Filter by search term
    get export_csv_invoices_url, params: { invoice_type: "sale", search: "DRAFT-200", archived: "false", quote: "false" }
    assert_response :success
    assert_includes response.body, "INV-DRAFT-200"
    assert_not_includes response.body, "INV-PAID-100"

    # Filter by quote: true
    get export_csv_invoices_url, params: { invoice_type: "sale", quote: "true", archived: "false" }
    assert_response :success
    assert_includes response.body, "Q-QUOTE-300"
    assert_not_includes response.body, "INV-PAID-100"

    # Filter by archived: true
    get export_csv_invoices_url, params: { invoice_type: "sale", archived: "true", quote: "false" }
    assert_response :success
    assert_includes response.body, "INV-ARCH-400"
    assert_not_includes response.body, "INV-PAID-100"
  end

  test "export_csv sanitizes cells against formula injection (CWE-1236)" do
    malicious_company = Company.create!(name: "=cmd|' /C calc'!A0", user: @user)
    Invoice.create!(
      user: @user,
      recipient_company: malicious_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "+@SUM(1+1)",
      recipient_note: "-DDE(\"cmd\";\"/C calc\";\"__proc\")"
    )

    get export_csv_invoices_url, params: { invoice_type: "sale" }
    assert_response :success
    body = response.body

    # Ensure dangerous formula prefixes are escaped with a prepended single quote (')
    assert_includes body, "'=cmd|' /C calc'!A0"
    assert_includes body, "'+@SUM(1+1)"
    assert_includes body, "'-DDE(\"\"cmd\"\";\"\"/C calc\"\";\"\"__proc\"\")"

    # Also verify with CSV.parse that parsed cell values have the leading single quote
    parsed_rows = CSV.parse(body.delete_prefix("\uFEFF"))
    data_row = parsed_rows.last
    assert_equal "'+@SUM(1+1)", data_row[0]
    assert_equal "'=cmd|' /C calc'!A0", data_row[6]
    assert_equal "'-DDE(\"cmd\";\"/C calc\";\"__proc\")", data_row[17]
  end

  test "export_csv enforces user multi-tenancy and does not leak other users invoices" do
    other_user = User.create!(
      email: "other_tenant_#{Time.now.to_i}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    other_company = Company.create!(name: "Other Tenant Inc", user: other_user)
    Invoice.create!(
      user: other_user,
      recipient_company: other_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "OTHER-TENANT-SECRET-999"
    )

    my_company = Company.create!(name: "My Tenant Inc", user: @user)
    Invoice.create!(
      user: @user,
      recipient_company: my_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "MY-TENANT-INV-001"
    )

    get export_csv_invoices_url, params: { invoice_type: "sale" }
    assert_response :success
    assert_includes response.body, "MY-TENANT-INV-001"
    assert_not_includes response.body, "OTHER-TENANT-SECRET-999"
  end

  test "index page renders export csv button and sub-tab export buttons" do
    get invoices_url
    assert_response :success
    assert_select "button#exportInvoicesBtn", text: /Export CSV/
    assert_select "button.export-invoices-sub-btn", minimum: 1
  end

  test "index page renders create document dropdown with invoice, quote, and credit note options" do
    get invoices_url
    assert_response :success
    assert_select "button#createDocumentDropdown", text: /Create Document/
    assert_select "ul[aria-labelledby='createDocumentDropdown']" do
      assert_select "a[href*='/invoices/new']", text: /Create Invoice/
      assert_select "a[href*='category=quote']", text: /Create Quote/
      assert_select "a[href*='category=credit_note']", text: /Create Credit Note/
    end
  end

  test "datatable returns checkbox column" do
    Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-CHK-01",
      status: "draft"
    )

    get datatable_data_invoices_url, params: { invoice_type: "sale", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
    assert data.first.key?("checkbox")
    assert_match /invoice-row-checkbox/, data.first["checkbox"]
  end

  test "bulk_action archives selected invoices" do
    inv1 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-ARC-1", archived: false)
    inv2 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-ARC-2", archived: false)

    post bulk_action_invoices_url, params: {
      bulk_action: "archive",
      invoice_ids: [inv1.id, inv2.id],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "Successfully archived 2 invoices.", flash[:notice]
    assert inv1.reload.archived?
    assert inv2.reload.archived?
  end

  test "bulk_action unarchives selected invoices" do
    inv1 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-UNARC-1", archived: true)
    inv2 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-UNARC-2", archived: true)

    post bulk_action_invoices_url, params: {
      bulk_action: "unarchive",
      invoice_ids: [inv1.id, inv2.id],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "Successfully unarchived 2 invoices.", flash[:notice]
    assert_not inv1.reload.archived?
    assert_not inv2.reload.archived?
  end

  test "bulk_action destroys selected invoices" do
    inv1 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-DEL-1")
    inv2 = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-DEL-2")

    post bulk_action_invoices_url, params: {
      bulk_action: "destroy",
      invoice_ids: [inv1.id, inv2.id],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "Successfully deleted 2 invoices.", flash[:notice]
    assert_not Invoice.exists?(inv1.id)
    assert_not Invoice.exists?(inv2.id)
  end

  test "bulk_action marks invoices as paid and synchronizes counterpart purchase invoice" do
    seller_company = Company.create!(name: "Seller Co", user: @user)
    buyer_user = User.create!(email: "buyer_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    buyer_company = Company.create!(name: "Buyer Co", user: buyer_user)

    sale_inv = Invoice.create!(
      user: @user,
      recipient_company: buyer_company,
      sale_from: seller_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-SYNC-01",
      status: "sent"
    )

    purchase_inv = Invoice.create!(
      user: buyer_user,
      recipient_company: buyer_company,
      sale_from: seller_company,
      invoice_type: "purchase",
      invoice_category: "standard",
      invoice_number: "INV-SYNC-01",
      status: "pending"
    )

    post bulk_action_invoices_url, params: {
      bulk_action: "mark_paid",
      invoice_ids: [sale_inv.id],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "Successfully updated 1 invoice to Paid.", flash[:notice]
    assert_equal "paid", sale_inv.reload.status
    assert_equal "paid", purchase_inv.reload.status
  end

  test "bulk_action updates status to approved, rejected, and draft" do
    inv_approved = Invoice.create!(user: @user, invoice_type: "purchase", invoice_category: "standard", invoice_number: "INV-APP-1", status: "pending")
    post bulk_action_invoices_url, params: {
      bulk_action: "mark_approved",
      invoice_ids: [inv_approved.id],
      tab: "purchase-invoices"
    }
    assert_equal "approved", inv_approved.reload.status

    inv_rejected = Invoice.create!(user: @user, invoice_type: "purchase", invoice_category: "standard", invoice_number: "INV-REJ-1", status: "pending")
    post bulk_action_invoices_url, params: {
      bulk_action: "mark_rejected",
      invoice_ids: [inv_rejected.id],
      tab: "purchase-invoices"
    }
    assert_equal "rejected", inv_rejected.reload.status

    inv_draft = Invoice.create!(user: @user, invoice_type: "sale", invoice_category: "standard", invoice_number: "INV-DRF-1", status: "sent")
    post bulk_action_invoices_url, params: {
      bulk_action: "mark_draft",
      invoice_ids: [inv_draft.id],
      tab: "sales-invoices"
    }
    assert_equal "draft", inv_draft.reload.status
  end

  test "bulk_action strictly enforces tenant isolation and prevents modifying other users invoices" do
    other_user = User.create!(email: "victim_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    other_inv = Invoice.create!(user: other_user, invoice_type: "sale", invoice_category: "standard", invoice_number: "OTHER-USER-INV", archived: false)

    post bulk_action_invoices_url, params: {
      bulk_action: "archive",
      invoice_ids: [other_inv.id],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "No authorized invoices found to perform this action.", flash[:alert]
    assert_not other_inv.reload.archived?
  end

  test "bulk_action handles empty or invalid selections gracefully" do
    post bulk_action_invoices_url, params: {
      bulk_action: "archive",
      invoice_ids: [],
      tab: "sales-invoices"
    }

    assert_redirected_to invoices_path(tab: "sales-invoices")
    assert_equal "No invoices selected.", flash[:alert]
  end
end

