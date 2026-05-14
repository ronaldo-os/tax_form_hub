# frozen_string_literal: true

class GenerateRecurringInvoicesJob < ApplicationJob
  queue_as :default

  # Generate invoices for all subscriptions due for invoicing
  #
  # This job runs periodically (typically daily) to:
  # 1. Find all subscriptions with next_invoice_date <= today
  # 2. Generate new invoices for each due subscription
  # 3. Update subscription renewal information
  # 4. Track job execution for monitoring
  def perform(on_date: Date.current)
    subscriptions = Subscription.due_for_invoicing(on_date)
    
    Rails.logger.info "GenerateRecurringInvoicesJob: Found #{subscriptions.count} subscriptions due for invoicing"

    results = {
      total: subscriptions.count,
      successful: 0,
      failed: 0,
      errors: []
    }

    subscriptions.each do |subscription|
      begin
        invoice = subscription.generate_next_invoice
        results[:successful] += 1
        Rails.logger.info "Generated invoice #{invoice.invoice_number} for subscription #{subscription.id}"
      rescue StandardError => e
        results[:failed] += 1
        error_msg = "Subscription #{subscription.id}: #{e.message}"
        results[:errors] << error_msg
        Rails.logger.error error_msg
      end
    end

    log_job_result(results)
    results
  end

  private

  def log_job_result(results)
    Rails.logger.info "GenerateRecurringInvoicesJob completed: #{results[:successful]} successful, #{results[:failed]} failed"
    results[:errors].each do |error|
      Rails.logger.warn error
    end
  end
end
