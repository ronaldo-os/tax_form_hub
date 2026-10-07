require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  setup do
    @user = User.find_by(email: "jane_test@example.com") || User.create!(
      email: "jane_test@example.com",
      name: "Jane",
      password: "SecurePass#2026!xyz"
    )

    @company = Company.create!(name: "Acme Corp", user: @user)

    @invoice = Invoice.create!(
      user: @user,
      invoice_number: "INV-ACT-001",
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft",
      total: { "grand_total" => 500.0 }
    )

    @tax_submission = TaxSubmission.create!(
      company: @company,
      invoice: @invoice,
      email: "jane_test@example.com",
      details: "Test submission details"
    )
  end

  test "can create activity with polymorphic trackable" do
    activity = Activity.create!(
      trackable: @invoice,
      user: @user,
      action: "invoice_created",
      description: "Jane created Invoice #INV-ACT-001 on Oct 2"
    )

    assert activity.persisted?
    assert_equal @invoice, activity.trackable
    assert_equal @user, activity.user
    assert_equal "Jane", activity.actor_name
    assert_equal "J", activity.actor_initial
    assert_includes @invoice.activities, activity
  end

  test "activity tracks tax submission" do
    activity = Activity.create!(
      trackable: @tax_submission,
      user: @user,
      action: "tax_submitted",
      description: "Jane submitted Form 2307 on Oct 2"
    )

    assert activity.persisted?
    assert_equal @tax_submission, activity.trackable
    assert_equal "tax_submitted", activity.action
    assert_includes @tax_submission.activities, activity
    assert_equal "Tax Submitted", activity.icon_config[:label]
  end

  test "actor name falls back to email username titleized if name is absent" do
    mark_user = User.find_by(email: "mark.doe@example.com") || User.create!(
      email: "mark.doe@example.com",
      password: "SecurePass#2026!xyz"
    )

    activity = Activity.create!(
      trackable: @invoice,
      user: mark_user,
      action: "marked_as_paid",
      description: "Mark marked Invoice as Paid on Oct 3"
    )

    assert_equal "Mark Doe", activity.actor_name
    assert_equal "M", activity.actor_initial
    assert_equal "Paid", activity.icon_config[:label]
  end
end
