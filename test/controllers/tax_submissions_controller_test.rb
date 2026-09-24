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

  test "bulk archive archives multiple tax submissions and syncs invoices" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 1", archived: false)
    invoice2 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    sub2 = TaxSubmission.create!(company: @company, invoice: invoice2, email: @user.email, details: "Sub 2", archived: false)

    post bulk_action_tax_submissions_url, params: {
      bulk_action: "archive",
      tax_submission_ids: [sub1.id, sub2.id]
    }

    assert_response :redirect
    assert_equal "Successfully archived 2 submissions.", flash[:notice]

    assert sub1.reload.archived?, "Sub 1 should be archived"
    assert sub2.reload.archived?, "Sub 2 should be archived"
    assert @invoice.reload.archived?, "Associated invoice should be archived"
    assert invoice2.reload.archived?, "Associated invoice 2 should be archived"
  end

  test "bulk unarchive unarchives multiple archived tax submissions and syncs invoices" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 1", archived: true)
    @invoice.update!(archived: true)
    invoice2 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid", archived: true)
    sub2 = TaxSubmission.create!(company: @company, invoice: invoice2, email: @user.email, details: "Sub 2", archived: true)

    post bulk_action_tax_submissions_url, params: {
      bulk_action: "unarchive",
      tax_submission_ids: [sub1.id, sub2.id]
    }

    assert_response :redirect
    assert_equal "Successfully unarchived 2 submissions.", flash[:notice]

    assert_not sub1.reload.archived?, "Sub 1 should be unarchived"
    assert_not sub2.reload.archived?, "Sub 2 should be unarchived"
    assert_not @invoice.reload.archived?, "Associated invoice should be unarchived"
    assert_not invoice2.reload.archived?, "Associated invoice 2 should be unarchived"
  end

  test "bulk delete deletes multiple pending tax submissions" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 1")
    invoice2 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    sub2 = TaxSubmission.create!(company: @company, invoice: invoice2, email: @user.email, details: "Sub 2")

    assert_difference("TaxSubmission.count", -2) do
      post bulk_action_tax_submissions_url, params: {
        bulk_action: "destroy",
        tax_submission_ids: [sub1.id, sub2.id]
      }
    end

    assert_response :redirect
    assert_equal "Successfully deleted 2 submissions.", flash[:notice]
    assert_nil TaxSubmission.find_by(id: sub1.id)
    assert_nil TaxSubmission.find_by(id: sub2.id)
  end

  test "bulk delete skips submissions that are already reviewed or processed" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Pending")
    invoice2 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    sub2 = TaxSubmission.create!(company: @company, invoice: invoice2, email: @user.email, details: "Reviewed", reviewed: true)

    assert_difference("TaxSubmission.count", -1) do
      post bulk_action_tax_submissions_url, params: {
        bulk_action: "destroy",
        tax_submission_ids: [sub1.id, sub2.id]
      }
    end

    assert_response :redirect
    assert_includes flash[:notice], "Successfully deleted 1 submission."
    assert_includes flash[:notice], "1 submission skipped because already processed or reviewed."
    assert_nil TaxSubmission.find_by(id: sub1.id)
    assert_not_nil TaxSubmission.find_by(id: sub2.id)
  end

  test "bulk action validates empty selection" do
    post bulk_action_tax_submissions_url, params: {
      bulk_action: "archive",
      tax_submission_ids: []
    }

    assert_response :redirect
    assert_equal "No submissions selected.", flash[:alert]
  end

  test "bulk action prevents modifying or deleting submissions belonging to another user" do
    other_user = User.create!(email: "other_user_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    other_company = Company.create!(name: "Other Company", user: other_user)
    other_invoice = Invoice.create!(user: other_user, recipient_company: other_company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    other_sub = TaxSubmission.create!(company: other_company, invoice: other_invoice, email: other_user.email, details: "Secret Sub")

    # Current user tries to bulk delete other_user's submission
    assert_no_difference("TaxSubmission.count") do
      post bulk_action_tax_submissions_url, params: {
        bulk_action: "destroy",
        tax_submission_ids: [other_sub.id]
      }
    end

    assert_response :redirect
    assert_equal "No authorized submissions found to perform this action.", flash[:alert]
    assert_not_nil TaxSubmission.find_by(id: other_sub.id)
  end

  test "home page renders checkboxes and bulk action bar for sent submissions" do
    other_user = User.create!(email: "target_user_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    target_company = Company.create!(name: "Target Vendor UI", user: other_user)
    tax_submission = TaxSubmission.create!(company: target_company, invoice: @invoice, email: @user.email, details: "UI Check")

    get tax_submissions_home_url
    assert_response :success

    # Verify Bulk Action Bar is present
    assert_select "div.tax-submissions-bulk-bar"
    assert_select "form.bulk-submissions-form[action='#{bulk_action_tax_submissions_path}']"

    # Verify checkboxes
    assert_select "input.master-bulk-checkbox"
    assert_select "input.table-header-checkbox"
    assert_select "input.submission-row-checkbox[value='#{tax_submission.id}']"

    # Verify action buttons
    assert_select "button[value='archive']"
    assert_select "button[value='destroy']"
  end

  test "index page renders checkboxes and bulk action bar for incoming submissions" do
    tax_submission = TaxSubmission.create!(company: @company, invoice: @invoice, email: "incoming_sender@example.com", details: "Incoming UI Check")

    get tax_submissions_url
    assert_response :success

    # Verify Bulk Action Bar is present
    assert_select "div.tax-submissions-bulk-bar"
    assert_select "form.bulk-submissions-form[action='#{bulk_action_tax_submissions_path}']"

    # Verify checkboxes
    assert_select "input.master-bulk-checkbox"
    assert_select "input.table-header-checkbox"
    assert_select "input.submission-row-checkbox[value='#{tax_submission.id}']"

    # Verify action buttons
    assert_select "button[value='archive']"
    assert_select "button[value='destroy']"
  end
end
