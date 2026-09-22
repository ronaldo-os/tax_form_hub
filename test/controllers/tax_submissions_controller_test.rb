require "test_helper"

class TaxSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "tax_test_#{Time.now.to_i}_#{rand(1000)}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    @company = Company.create!(name: "Test Company #{Time.now.to_i}", user: @user)
    @user.update(company: @company)
    @invoice = Invoice.create!(
      user: @user,
      recipient_company: @company,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "paid"
    )
    sign_in @user
  end

  test "home page renders form 2307 attachment file name in modal" do
    other_user = User.create!(email: "other_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    target_company = Company.create!(name: "Target Vendor", user: other_user)
    tax_submission = TaxSubmission.create!(
      company: target_company,
      invoice: @invoice,
      email: @user.email,
      details: "Test submission"
    )

    file = fixture_file_upload(Rails.root.join("test", "fixtures", "files", "test_image.png"), "image/png")
    tax_submission.form_2307.attach(file)

    get tax_submissions_home_url
    assert_response :success
    assert_select "div#form2307Modal-#{tax_submission.id}" do
      assert_select "span[title='test_image.png']", text: "test_image.png"
    end
  end

  test "show js partial renders form 2307 attachment file name in details modal" do
    other_user = User.create!(email: "other2_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    target_company = Company.create!(name: "Target Vendor 2", user: other_user)
    tax_submission = TaxSubmission.create!(
      company: target_company,
      invoice: @invoice,
      email: @user.email,
      details: "Test submission details"
    )

    file = fixture_file_upload(Rails.root.join("test", "fixtures", "files", "test_image.png"), "image/png")
    tax_submission.form_2307.attach(file)

    get tax_submission_url(tax_submission, format: :js), xhr: true
    assert_response :success
    assert_includes response.body, "test_image.png"
  end

  test "index page renders form 2307 attachment file name for incoming submissions" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming submission"
    )

    # Attach file with blob specifying a long filename
    tax_submission.form_2307.attach(
      io: StringIO.new("%PDF-1.4 test content"),
      filename: "very_long_form_2307_attachment_filename_spec_2026.pdf",
      content_type: "application/pdf"
    )

    get tax_submissions_url
    assert_response :success
    assert_select "div#form2307Modal-#{tax_submission.id}" do
      assert_select "span.text-truncate[title='very_long_form_2307_attachment_filename_spec_2026.pdf']",
                    text: "very_long_form_2307_attachment_filename_spec_2026.pdf"
      assert_select "embed[type='application/pdf']"
    end
  end

  test "home page renders export csv button and submission row data attributes for bookkeeping" do
    other_user = User.create!(email: "other_csv_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    target_company = Company.create!(name: "Target Vendor CSV", tax_id_number: "123-456-789-000", user: other_user)
    @invoice.update!(
      invoice_number: "INV-2026-CSV-01",
      issue_date: Date.current,
      currency: "PHP",
      total: { "subtotal" => "10000.00", "tax" => "200.00", "grand_total" => "10200.00" }
    )
    tax_submission = TaxSubmission.create!(
      company: target_company,
      invoice: @invoice,
      email: @user.email,
      details: "Detailed notes for financial reporting"
    )

    get tax_submissions_home_url
    assert_response :success

    # Verify Export CSV button is present
    assert_select "button#exportTaxSubmissionsBtn", text: /Export CSV/

    # Verify table row contains required CSV data attributes
    assert_select "tr[data-transaction-id='#{tax_submission.user_transaction_id}']" do
      assert_select "[data-company-name='Target Vendor CSV']"
      assert_select "[data-company-tin='123-456-789-000']"
      assert_select "[data-invoice-number='INV-2026-CSV-01']"
      assert_select "[data-currency='PHP']"
      assert_select "[data-subtotal='10000.00']"
      assert_select "[data-tax-amount='200.00']"
      assert_select "[data-grand-total='10200.00']"
      assert_select "[data-status='Pending']"
      assert_select "[data-archived='Active']"
    end
  end

  test "index page renders export csv button and incoming submission row data attributes" do
    @invoice.update!(
      invoice_number: "INV-INCOMING-CSV-02",
      issue_date: Date.current,
      currency: "USD",
      total: { "subtotal" => "500.00", "tax" => "50.00", "grand_total" => "550.00" }
    )
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "client_sender@example.com",
      details: "Incoming payment report"
    )

    get tax_submissions_url
    assert_response :success

    # Verify Export CSV button is present
    assert_select "button#exportIncomingSubmissionsBtn", text: /Export CSV/

    # Verify incoming table row contains required data attributes
    assert_select "tr[data-transaction-id='#{tax_submission.company_submission_id}']" do
      assert_select "[data-email='client_sender@example.com']"
      assert_select "[data-invoice-number='INV-INCOMING-CSV-02']"
      assert_select "[data-currency='USD']"
      assert_select "[data-subtotal='500.00']"
      assert_select "[data-grand-total='550.00']"
    end
  end
end
