# frozen_string_literal: true

class GenerateRecurringInvoicesJob < ApplicationJob
  queue_as :default

  # Generate invoices for all subscriptions due for invoicing
  #
  # RECURRING INVOICE WORKFLOW:
  # - First invoice created for subscription: Parent/primary invoice (e.g., 2026-00001-009)
  # - Subsequent invoices: Sub-invoices linked to parent (e.g., 2026-00001-009-01, 2026-00001-009-02, etc.)
  #
  # This job runs periodically (typically daily) to:
  # 1. Find all subscriptions with next_invoice_date <= today
  # 2. Generate new invoices for each due subscription (automatically parent or sub-invoice)
  # 3. Link sub-invoices to their parent via recurring_parent_invoice_id
  # 4. Update subscription renewal information (current_period, next_invoice_date)
  # 5. Track job execution for monitoring
  #
  # IMPORTANT: Always reference the original invoice ID (parent) as the key link between invoices
  # See RECURRING_INVOICE_WORKFLOW.md for complete documentation
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
        invoice_type = invoice.recurring_parent_invoice? ? "parent" : "sub-invoice"
        parent_ref = invoice.recurring_parent_invoice_id ? " [parent: #{invoice.recurring_parent_invoice.invoice_number}]" : ""
        results[:successful] += 1
        Rails.logger.info "Generated #{invoice_type} invoice #{invoice.invoice_number}#{parent_ref} for subscription #{subscription.id}"
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
