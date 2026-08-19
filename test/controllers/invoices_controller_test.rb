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
end
