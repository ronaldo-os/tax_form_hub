require "test_helper"

class ActivityLoggerTest < ActiveSupport::TestCase
  setup do
    @jane = User.find_by(email: "jane@example.com") || User.create!(
      email: "jane@example.com",
      name: "Jane",
      password: "SecurePass#2026!xyz"
    )

    @mark = User.find_by(email: "mark@example.com") || User.create!(
      email: "mark@example.com",
      name: "Mark",
      password: "SecurePass#2026!xyz"
    )

    @john = User.find_by(email: "john@example.com") || User.create!(
      email: "john@example.com",
      name: "John",
      password: "SecurePass#2026!xyz"
    )

    @company = Company.create!(name: "Acme Global", user: @jane)

    @invoice = Invoice.create!(
      user: @jane,
      invoice_number: "INV-LOG-100",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft",
      total: { "grand_total" => 500.0 }
    )

    @tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "jane@example.com",
      details: "Quarterly 2307 Form"
    )
  end

  test "logs tax submission for both submission and invoice (Jane submitted Form 2307)" do
    assert_difference("Activity.count", 2) do
      ActivityLogger.log_tax_submitted(@tax_submission, @jane)
    end

    sub_activity = @tax_submission.activities.recent.first
    assert_match /Jane submitted Form 2307/, sub_activity.description
    assert_equal "tax_submitted", sub_activity.action
    assert_equal "Acme Global", sub_activity.company_name

    inv_activity = @invoice.activities.recent.first
    assert_match /Jane submitted Form 2307/, inv_activity.description
    assert_equal "tax_submitted", inv_activity.action
    assert_equal "Acme Global", inv_activity.company_name
  end

  test "logs invoice marked as paid (Mark marked Invoice as Paid)" do
    assert_difference("Activity.count", 1) do
      ActivityLogger.log_invoice_paid(@invoice, @mark)
    end

    activity = @invoice.activities.recent.first
    assert_match /Mark marked Invoice as Paid/, activity.description
    assert_equal "marked_as_paid", activity.action
  end

  test "logs invoice amount updated (John updated the invoice amount)" do
    assert_difference("Activity.count", 1) do
      ActivityLogger.log_invoice_amount_updated(@invoice, @john, 500.0, 750.0)
    end

    activity = @invoice.activities.recent.first
    assert_match /John updated the invoice amount/, activity.description
    assert_equal "amount_updated", activity.action
    assert_equal 500.0, activity.metadata["old_amount"]
    assert_equal 750.0, activity.metadata["new_amount"]
  end

  test "logs tax status updated for reviewed and processed" do
    ActivityLogger.log_tax_status_updated(@tax_submission, @mark, "reviewed", true)
    activity = @tax_submission.activities.recent.first
    assert_match /Mark marked submission as Reviewed/, activity.description
    assert_equal "reviewed", activity.action

    ActivityLogger.log_tax_status_updated(@tax_submission, @mark, "processed", true)
    activity2 = @tax_submission.activities.recent.first
    assert_match /Mark marked submission as Processed/, activity2.description
    assert_equal "processed", activity2.action
  end

  test "logs activity with actor company details" do
    ActivityLogger.log_invoice_created(@invoice, @jane)
    activity = @invoice.activities.recent.first
    assert_equal "Jane", activity.user_name
    assert_equal "Acme Global", activity.company_name
    assert_equal "Acme Global", activity.metadata["company_name"]
  end
end
