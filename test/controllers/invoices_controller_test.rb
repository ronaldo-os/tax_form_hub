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
    assert_match /d-flex align-items-center justify-content-center/, attachment_html
    assert_match /object-fit: contain/, attachment_html
    assert_match /max-height: 70vh/, attachment_html
  end
end
