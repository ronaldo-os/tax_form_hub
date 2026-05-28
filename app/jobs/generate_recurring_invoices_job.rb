# frozen_string_literal: true

class GenerateRecurringInvoicesJob < ApplicationJob
  queue_as :default

  # Generate invoices for all subscription contracts due for billing
  #
  # SUBSCRIPTION-BASED RECURRING INVOICE WORKFLOW:
  # - Parent invoice acts as the subscription contract (e.g., 2026-00001-009)
  # - Subsequent invoices are generated monthly linked to parent (e.g., 2026-00001-009-01, 2026-00001-009-02, etc.)
  #
  # This job runs periodically (typically daily) to:
  # 1. Find all invoices with subscription line-items due for billing
  # 2. Generate new invoices for each due subscription contract
  # 3. Link generated invoices to their parent via recurring_parent_invoice_id
  # 4. Update parent invoice line items with new renewal dates
  # 5. Track job execution for monitoring
  #
  # IMPORTANT: Always reference the original invoice number (parent) as the billing reference
  def perform(on_date: Date.current)
    subscription_contracts = Invoice.subscription_contracts_due_for_billing(on_date)
    
    # Filter to only those with subscription line-items that are due
    due_contracts = subscription_contracts.select(&:subscription_due_for_billing?)
    
    Rails.logger.info "GenerateRecurringInvoicesJob: Found #{due_contracts.count} subscription contracts due for billing"

    results = {
      total: due_contracts.count,
      successful: 0,
      failed: 0,
      errors: []
    }

    due_contracts.each do |subscription_contract|
      begin
        invoice = subscription_contract.generate_subscription_invoice
        results[:successful] += 1
        Rails.logger.info "Generated subscription invoice #{invoice.invoice_number} for contract #{subscription_contract.invoice_number}"
      rescue StandardError => e
        results[:failed] += 1
        error_msg = "Subscription contract #{subscription_contract.invoice_number}: #{e.message}"
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
