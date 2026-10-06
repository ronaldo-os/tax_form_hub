# frozen_string_literal: true

require "test_helper"

class GenerateRecurringInvoicesJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @user = User.create!(
      email: "owner_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @customer = Company.create!(name: "Test Client Inc", user: @user)

    @parent_invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "2026-00001-#{rand(100..999)}",
      recipient_company: @customer,
      currency: "PHP",
      line_items_data: [
        {
          "description" => "Recurring Cloud Subscription",
          "quantity" => "1",
          "price" => "5000.00",
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
  end

  test "successful recurring invoice generation generates invoice and clears any prior error" do
    # Set a previous recurring generation error
    @parent_invoice.update_column(
      :invoice_info,
      {
        "recurring_generation_error" => {
          "message" => "Previous transient error",
          "failed_at" => 1.day.ago.iso8601,
          "attempted_date" => Date.current.to_s
        }
      }
    )

    results = GenerateRecurringInvoicesJob.perform_now(on_date: (Date.current + 1.month))

    assert_equal 1, results[:successful]
    assert_equal 0, results[:failed]
    assert_equal 1, results[:invoices_generated]

    @parent_invoice.reload
    assert_nil @parent_invoice.invoice_info["recurring_generation_error"]
    assert_equal 1, @parent_invoice.recurring_sub_invoices.count
  end

  test "failed recurring invoice generation logs error, records failure details, and sends in-app notification and email" do
    # Simulate a generation failure by stubbing generate_subscription_invoices to raise an error
    error_message = "Payment gateway timeout or invalid line item state"
    
    Invoice.any_instance.stubs(:generate_subscription_invoices).raises(StandardError.new(error_message)) rescue nil
    # If mocha is not installed, use standard alias/override or mock
    Invoice.class_eval do
      alias_method :orig_generate_subscription_invoices, :generate_subscription_invoices
      def generate_subscription_invoices(on_date = Date.current)
        raise StandardError, "Payment gateway timeout or invalid line item state"
      end
    end

    assert_enqueued_emails 1 do
      assert_difference("Notification.count", 1) do
        results = GenerateRecurringInvoicesJob.perform_now(on_date: (Date.current + 1.month))
        assert_equal 1, results[:failed]
        assert_includes results[:errors].first, error_message
      end
    end

    # Verify notification details
    notification = @user.notifications.recent.first
    assert_not_nil notification
    assert_equal "invoices", notification.category
    assert_equal "recurring_invoice_failed", notification.action
    assert_equal "Recurring Invoice Generation Failed", notification.title
    assert_includes notification.message, @parent_invoice.invoice_number
    assert_includes notification.message, error_message
    assert_equal "/subscriptions/#{@parent_invoice.id}", notification.target_url
    assert_equal @parent_invoice, notification.notifiable

    # Verify error recorded on the contract invoice
    @parent_invoice.reload
    error_data = @parent_invoice.invoice_info["recurring_generation_error"]
    assert_not_nil error_data
    assert_equal error_message, error_data["message"]
    assert_not_nil error_data["failed_at"]

    # Verify email content by delivering enqueued jobs
    perform_enqueued_jobs

    email = ActionMailer::Base.deliveries.last
    assert_not_nil email
    assert_equal [@user.email], email.to
    assert_includes email.subject, "Recurring invoice generation failed"
    assert_includes email.subject, @parent_invoice.invoice_number
    assert_includes email.body.encoded, error_message
    assert_includes email.body.encoded, @parent_invoice.invoice_number
  ensure
    # Restore original method
    Invoice.class_eval do
      if method_defined?(:orig_generate_subscription_invoices)
        alias_method :generate_subscription_invoices, :orig_generate_subscription_invoices
        remove_method :orig_generate_subscription_invoices
      end
    end
  end

  test "Notification icon_config for recurring_invoice_failed is styled correctly" do
    notif = Notification.new(action: "recurring_invoice_failed", category: "invoices")
    config = notif.icon_config
    assert_equal "fa-solid fa-triangle-exclamation", config[:icon]
    assert_equal "text-danger", config[:color]
    assert_equal "bg-danger-subtle", config[:bg]
  end
end
