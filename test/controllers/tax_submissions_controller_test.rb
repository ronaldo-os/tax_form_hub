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
      assert_select "span.text-break[title='very_long_form_2307_attachment_filename_spec_2026.pdf']",
                    text: "very_long_form_2307_attachment_filename_spec_2026.pdf"
      assert_select "a", text: "View PDF"
    end
  end
end
