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
end
