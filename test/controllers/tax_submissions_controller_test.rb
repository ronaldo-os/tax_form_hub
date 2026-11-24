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

  test "bulk archive does not archive unselected tax submissions belonging to the same invoice" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 1", archived: false)
    sub2 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 2", archived: false)

    post bulk_action_tax_submissions_url, params: {
      bulk_action: "archive",
      tax_submission_ids: [sub1.id]
    }

    assert_response :redirect
    assert_equal "Successfully archived 1 submission.", flash[:notice]
    assert sub1.reload.archived?, "Selected sub 1 should be archived"
    assert_not sub2.reload.archived?, "Unselected sub 2 should NOT be archived"
    assert_not @invoice.reload.archived?, "Invoice should remain active while sub 2 is active"
  end

  test "bulk unarchive does not unarchive unselected tax submissions belonging to the same invoice" do
    sub1 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 1", archived: true)
    sub2 = TaxSubmission.create!(company: @company, invoice: @invoice, email: @user.email, details: "Sub 2", archived: true)
    @invoice.update_columns(archived: true)

    post bulk_action_tax_submissions_url, params: {
      bulk_action: "unarchive",
      tax_submission_ids: [sub1.id]
    }

    assert_response :redirect
    assert_equal "Successfully unarchived 1 submission.", flash[:notice]
    assert_not sub1.reload.archived?, "Selected sub 1 should be unarchived"
    assert sub2.reload.archived?, "Unselected sub 2 should remain archived"
    assert_not @invoice.reload.archived?, "Invoice should be unarchived since sub 1 is active"
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

    # Verify checkboxes and allowed actions
    assert_select "input.master-bulk-checkbox"
    assert_select "input.table-header-checkbox"
    assert_select "input.submission-row-checkbox[value='#{tax_submission.id}'][data-allowed-actions='archive,destroy']"

    # Verify action buttons
    assert_select "button[value='archive']"
    assert_select "button[value='destroy']"
  end

  test "home page renders data-allowed-actions on row checkbox restricting delete when reviewed or processed" do
    other_user = User.create!(email: "target_user_restrict_#{Time.now.to_i}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    target_company = Company.create!(name: "Target Vendor Restrict", user: other_user)
    
    # 1. Pending submission allows archive and destroy
    sub_pending = TaxSubmission.create!(company: target_company, invoice: @invoice, email: @user.email, details: "Pending Sub")

    # 2. Reviewed submission allows only archive (destroy restricted)
    invoice2 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    sub_reviewed = TaxSubmission.create!(company: target_company, invoice: invoice2, email: @user.email, details: "Reviewed Sub", reviewed: true)

    # 3. Processed submission allows only archive (destroy restricted)
    invoice3 = Invoice.create!(user: @user, recipient_company: @company, invoice_type: "sale", invoice_category: "standard", status: "paid")
    sub_processed = TaxSubmission.create!(company: target_company, invoice: invoice3, email: @user.email, details: "Processed Sub", processed: true)

    get tax_submissions_home_url
    assert_response :success

    assert_select "input.submission-row-checkbox[value='#{sub_pending.id}'][data-allowed-actions='archive,destroy']"
    assert_select "input.submission-row-checkbox[value='#{sub_reviewed.id}'][data-allowed-actions='archive']"
    assert_select "input.submission-row-checkbox[value='#{sub_processed.id}'][data-allowed-actions='archive']"
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

  test "index page renders History column header and button for incoming submissions" do
    tax_submission = TaxSubmission.create!(company: @company, invoice: @invoice, email: "incoming_sender@example.com", details: "Incoming History Check")

    get tax_submissions_url
    assert_response :success

    assert_select "th", text: "History"
    assert_select "button.open-activity-timeline-btn[data-trackable-id='#{tax_submission.id}']"
  end

  test "create logs activity for both tax submission and invoice" do
    assert_difference("Activity.count", 2) do
      post tax_submissions_url, params: {
        tax_submission: {
          invoice_id: @invoice.id,
          details: "Form 2307 Filing",
          email: @user.email
        }
      }
    end

    created_sub = TaxSubmission.order(created_at: :desc).first
    sub_activity = created_sub.activities.recent.first
    assert_match /submitted Form 2307/, sub_activity.description
    assert_equal "tax_submitted", sub_activity.action

    inv_activity = @invoice.activities.recent.first
    assert_match /submitted Form 2307/, inv_activity.description
  end

  test "create retains current page and query params from redirect_url" do
    target_page_url = "/tax_submissions/home?page=2&status=Pending&tab=archived"
    post tax_submissions_url, params: {
      redirect_url: target_page_url,
      tax_submission: {
        invoice_id: @invoice.id,
        details: "Form 2307 on page 2",
        email: @user.email
      }
    }

    assert_response :redirect
    assert_redirected_to target_page_url
    assert_equal "Tax documents submitted successfully.", flash[:notice]
  end

  test "create strips modal and prefill params while retaining page and filters" do
    url_with_modal = "/tax_submissions/home?open_modal=true&invoice_id=99&company_id=88&page=3&status=Reviewed"
    post tax_submissions_url, params: {
      redirect_url: url_with_modal,
      tax_submission: {
        invoice_id: @invoice.id,
        details: "Form 2307 Filing",
        email: @user.email
      }
    }

    assert_response :redirect
    assert_redirected_to "/tax_submissions/home?page=3&status=Reviewed"
  end

  test "create falls back to referer retaining current page when redirect_url is omitted" do
    referrer_url = "http://www.example.com/tax_submissions/home?page=4&tab=active"
    post tax_submissions_url, params: {
      tax_submission: {
        invoice_id: @invoice.id,
        details: "Form 2307 Filing",
        email: @user.email
      }
    }, headers: { "HTTP_REFERER" => referrer_url }

    assert_response :redirect
    assert_redirected_to "/tax_submissions/home?page=4&tab=active"
  end

  test "create falls back to tax_submissions_home_path when no redirect_url or referer is provided" do
    post tax_submissions_url, params: {
      tax_submission: {
        invoice_id: @invoice.id,
        details: "Form 2307 Filing",
        email: @user.email
      }
    }

    assert_response :redirect
    assert_redirected_to tax_submissions_home_path
  end

  test "create sanitizes external redirect_url to prevent open redirect" do
    post tax_submissions_url, params: {
      redirect_url: "https://evil.example.com/phishing",
      tax_submission: {
        invoice_id: @invoice.id,
        details: "Form 2307 Filing",
        email: @user.email
      }
    }

    assert_response :redirect
    assert_redirected_to tax_submissions_home_path
  end

  test "home page renders hidden redirect_url input in submit docs modal preserving query parameters" do
    get tax_submissions_home_url(page: 2, tab: "archived")
    assert_response :success

    assert_select "input#tax_submission_redirect_url" do |inputs|
      assert_equal 1, inputs.length
      value = inputs.first["value"]
      assert_includes value, "page=2"
      assert_includes value, "tab=archived"
    end
  end

  test "show js partial renders reviewer quick actions for incoming submission recipient" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming tax submission",
      reviewed: false,
      processed: false
    )

    get tax_submission_url(tax_submission, format: :js), xhr: true
    assert_response :success
    assert_includes response.body, "reviewer-quick-actions-card"
    assert_includes response.body, "Reviewer Quick Actions"
    assert_includes response.body, "Mark as Reviewed"
    assert_includes response.body, "Mark as Processed"
    assert_includes response.body, "Pending"
  end

  test "show js partial toggles buttons to unmark when submission is reviewed or processed" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Reviewed and processed tax submission",
      reviewed: true,
      processed: true
    )

    get tax_submission_url(tax_submission, format: :js), xhr: true
    assert_response :success
    assert_includes response.body, "reviewer-quick-actions-card"
    assert_includes response.body, "Unmark Reviewed"
    assert_includes response.body, "Unmark Processed"
    assert_includes response.body, "Processed &amp; Reviewed"
  end

  test "show js partial does not render reviewer quick actions for non-reviewer sender" do
    other_user = User.create!(email: "vendor_#{Time.now.to_i}_#{rand(1000)}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    other_company = Company.create!(name: "Other Company #{Time.now.to_i}", user: other_user)
    
    # Submission sent to other_company, viewed by @user (sender)
    tax_submission = TaxSubmission.create!(
      company: other_company,
      invoice: @invoice,
      email: @user.email,
      details: "Sent by user"
    )

    get tax_submission_url(tax_submission, format: :js), xhr: true
    assert_response :success
    refute_includes response.body, "reviewer-quick-actions-card"
  end

  test "update toggles reviewed and redirects to redirect_to with open_submission" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming submission",
      reviewed: false
    )

    target_redirect = "/tax_submissions?open_submission=#{tax_submission.id}"
    patch tax_submission_url(tax_submission), params: {
      tax_submission: { reviewed: 1 },
      redirect_to: target_redirect
    }

    assert_response :redirect
    assert_redirected_to target_redirect
    assert tax_submission.reload.reviewed?
  end

  test "update toggles processed and redirects to redirect_to with open_submission" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming submission",
      processed: false
    )

    target_redirect = "/tax_submissions?open_submission=#{tax_submission.id}"
    patch tax_submission_url(tax_submission), params: {
      tax_submission: { processed: 1 },
      redirect_to: target_redirect
    }

    assert_response :redirect
    assert_redirected_to target_redirect
    assert tax_submission.reload.processed?
  end

  test "update via js format toggles reviewed and updates modal and table row without page reload" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming submission",
      reviewed: false,
      processed: false
    )

    patch tax_submission_url(tax_submission, format: :js), params: {
      tax_submission: { reviewed: 1 }
    }, xhr: true

    assert_response :success
    assert tax_submission.reload.reviewed?
    assert_includes response.body, '$("#submissionModalBody").html('
    assert_includes response.body, "Unmark Reviewed"
    assert_includes response.body, "Reviewed"
    assert_includes response.body, "submission-row-#{tax_submission.id}"
  end

  test "update via js format toggles processed and updates modal and table row without page reload" do
    tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "sender@example.com",
      details: "Incoming submission",
      reviewed: true,
      processed: false
    )

    patch tax_submission_url(tax_submission, format: :js), params: {
      tax_submission: { processed: 1 }
    }, xhr: true

    assert_response :success
    assert tax_submission.reload.processed?
    assert_includes response.body, '$("#submissionModalBody").html('
    assert_includes response.body, "Unmark Processed"
    assert_includes response.body, "Processed &amp; Reviewed"
    assert_includes response.body, "submission-row-#{tax_submission.id}"
  end

  test "home page renders drag-and-drop upload areas for Form 2307 and Deposit Slip" do
    get tax_submissions_home_url
    assert_response :success
    assert_select "#submitDocsModal div.file-dropzone.tax-file-dropzone[role='button'][tabindex='0']", count: 2
    assert_select "#submitDocsModal div.tax-file-dropzone input#form_2307_input.file-upload-input[type='file']", count: 1
    assert_select "#submitDocsModal div.tax-file-dropzone input#deposit_slip_input.file-upload-input[type='file'][multiple='multiple']", count: 1
    assert_select "#form_2307_list", count: 1
    assert_select "#deposit_slip_list", count: 1
  end

  test "fetch_invoices returns eligible invoices ordered with the most recent first" do
    older_invoice = Invoice.create!(
      user: @user,
      recipient_company: @company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-OLD-001",
      status: "approved",
      created_at: 2.days.ago
    )
    newest_invoice = Invoice.create!(
      user: @user,
      recipient_company: @company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-NEW-002",
      status: "approved",
      created_at: 1.minute.from_now
    )

    get fetch_invoices_tax_submissions_url, params: { company_id: @company.id }, as: :json
    assert_response :success

    json = JSON.parse(response.body)
    returned_ids = json.map { |inv| inv["id"] }
    assert_equal newest_invoice.id, returned_ids.first, "Most recent invoice should be first for auto-selection"
    assert_includes returned_ids, older_invoice.id
  end

  test "home page displays both outgoing and incoming submissions in tabs on one page without incoming link button" do
    get tax_submissions_home_url
    assert_response :success

    # Outgoing and Incoming top-level tabs present on the same page
    assert_select "#submissionTabs #outgoing-submissions-tab.active", count: 1
    assert_select "#submissionTabs #incoming-submissions-tab", count: 1
    assert_select "#outgoing-submissions.show.active", count: 1
    assert_select "#incoming-submissions", count: 1

    # Both Outgoing and Incoming active/archived tables rendered on one page
    assert_select "#taxSubmissionsSentActive", count: 1
    assert_select "#taxSubmissionsSentArchived", count: 1
    assert_select "#taxSubmissionsTableActive", count: 1
    assert_select "#taxSubmissionsTableArchived", count: 1

    # No separate "Incoming Submissions" navigation link button
    assert_select "a[href='#{tax_submissions_path}']", count: 0

    # Deep-linking directly to incoming tab & archived subtab
    get tax_submissions_home_url(tab: "incoming", subtab: "archived")
    assert_response :success
    assert_select "#submissionTabs #incoming-submissions-tab.active", count: 1
    assert_select "#incoming-submissions.show.active", count: 1
    assert_select "#incoming-archived-tab.active", count: 1
    assert_select "#incoming-archived.show.active", count: 1
  end
end
