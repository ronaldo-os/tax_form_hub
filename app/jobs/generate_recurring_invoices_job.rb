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
    due_contracts = subscription_contracts.select { |contract| contract.subscription_due_for_billing?(on_date) }
    
    Rails.logger.info "GenerateRecurringInvoicesJob: Found #{due_contracts.count} subscription contracts due for billing"

    results = {
      total: due_contracts.count,
      successful: 0,
      failed: 0,
      invoices_generated: 0,
      errors: []
    }

    due_contracts.each do |subscription_contract|
      begin
        invoices = subscription_contract.generate_subscription_invoices(on_date)
        clear_recurring_error(subscription_contract)
        results[:successful] += 1
        results[:invoices_generated] += invoices.size
        invoices.each do |invoice|
          Rails.logger.info "Generated subscription invoice #{invoice.invoice_number} for contract #{subscription_contract.invoice_number}"
        end
      rescue StandardError => e
        results[:failed] += 1
        error_msg = "Subscription contract #{subscription_contract.invoice_number}: #{e.message}"
        results[:errors] << error_msg
        Rails.logger.error error_msg

        # Record error details on subscription contract for UI review/retry
        record_recurring_error(subscription_contract, e.message, on_date)

        # Send in-app notification and email to the business owner
        send_failure_notifications(subscription_contract, e.message, on_date)
      end
    end

    log_job_result(results)
    results
  end

  private

  def send_failure_notifications(contract, error_message, on_date)
    # Send in-app notification to business owner
    NotificationService.notify_recurring_invoice_failed(contract, error_message)

    # Send email notification to business owner
    InvoiceMailer.recurring_invoice_failed(contract, error_message, on_date).deliver_later
  rescue StandardError => notif_err
    Rails.logger.error "GenerateRecurringInvoicesJob: Failed to dispatch failure notifications for contract #{contract.try(:invoice_number)}: #{notif_err.message}"
  end

  def record_recurring_error(contract, message, on_date)
    return unless contract.respond_to?(:invoice_info)

    error_data = {
      'message' => message,
      'failed_at' => Time.current.iso8601,
      'attempted_date' => on_date.to_s
    }
    new_info = (contract.invoice_info || {}).merge('recurring_generation_error' => error_data)
    contract.update_column(:invoice_info, new_info)
  rescue StandardError => err
    Rails.logger.warn "GenerateRecurringInvoicesJob: Failed to record error on contract #{contract.try(:invoice_number)}: #{err.message}"
  end

  def clear_recurring_error(contract)
    return unless contract.respond_to?(:invoice_info) && contract.invoice_info.is_a?(Hash)
    return unless contract.invoice_info['recurring_generation_error'].present?

    new_info = contract.invoice_info.except('recurring_generation_error')
    contract.update_column(:invoice_info, new_info)
  rescue StandardError => err
    Rails.logger.warn "GenerateRecurringInvoicesJob: Failed to clear error on contract #{contract.try(:invoice_number)}: #{err.message}"
  end

  def log_job_result(results)
    Rails.logger.info "GenerateRecurringInvoicesJob completed: #{results[:successful]} successful, #{results[:failed]} failed"
    results[:errors].each do |error|
      Rails.logger.warn error
    end
  end
end
