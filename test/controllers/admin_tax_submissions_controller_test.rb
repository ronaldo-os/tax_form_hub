require "test_helper"

class AdminTaxSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(
      email: "superadmin_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      role: "superadmin"
    )
    @admin_company = Company.create!(name: "Admin Org #{Time.now.to_i}", user: @admin)
    @admin.update(company: @admin_company)

    @user = User.create!(
      email: "client_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Client Org #{Time.now.to_i}", user: @user)
    @user.update(company: @company)

    @invoice = Invoice.create!(
      user: @user,
      recipient_company: @company,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "paid"
    )

    @tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: @user.email,
      details: "Client tax submission",
      reviewed: false,
      processed: false
    )

    sign_in @admin
  end

  test "admin show js renders reviewer quick actions" do
    get admin_tax_submission_url(@tax_submission, format: :js), xhr: true
    assert_response :success
    assert_includes response.body, "reviewer-quick-actions-card"
    assert_includes response.body, "Mark as Reviewed"
    assert_includes response.body, "Mark as Processed"
  end

  test "admin show js toggles buttons to unmark when reviewed or processed" do
    @tax_submission.update!(reviewed: true, processed: true)

    get admin_tax_submission_url(@tax_submission, format: :js), xhr: true
    assert_response :success
    assert_includes response.body, "reviewer-quick-actions-card"
    assert_includes response.body, "Unmark Reviewed"
    assert_includes response.body, "Unmark Processed"
  end

  test "admin update toggles reviewed and redirects to redirect_to with open_submission" do
    target_redirect = "/admin/tax_submissions?open_submission=#{@tax_submission.id}"
    patch admin_tax_submission_url(@tax_submission), params: {
      tax_submission: { reviewed: 1 },
      redirect_to: target_redirect
    }

    assert_response :redirect
    assert_redirected_to target_redirect
    assert @tax_submission.reload.reviewed?
  end

  test "admin update toggles processed and redirects to redirect_to with open_submission" do
    target_redirect = "/admin/tax_submissions?open_submission=#{@tax_submission.id}"
    patch admin_tax_submission_url(@tax_submission), params: {
      tax_submission: { processed: 1 },
      redirect_to: target_redirect
    }

    assert_response :redirect
    assert_redirected_to target_redirect
    assert @tax_submission.reload.processed?
  end

  test "admin update via js format toggles reviewed without page reload" do
    patch admin_tax_submission_url(@tax_submission, format: :js), params: {
      tax_submission: { reviewed: 1 }
    }, xhr: true

    assert_response :success
    assert @tax_submission.reload.reviewed?
    assert_includes response.body, '$("#submissionModalBody").html('
    assert_includes response.body, "Unmark Reviewed"
    assert_includes response.body, "submission-row-#{@tax_submission.id}"
  end

  test "admin update via js format toggles processed without page reload" do
    @tax_submission.update!(reviewed: true)

    patch admin_tax_submission_url(@tax_submission, format: :js), params: {
      tax_submission: { processed: 1 }
    }, xhr: true

    assert_response :success
    assert @tax_submission.reload.processed?
    assert_includes response.body, '$("#submissionModalBody").html('
    assert_includes response.body, "Unmark Processed"
    assert_includes response.body, "submission-row-#{@tax_submission.id}"
  end
end

