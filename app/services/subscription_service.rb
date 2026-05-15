# frozen_string_literal: true

# Service for managing subscription lifecycle and operations
class SubscriptionService
  # Create a new subscription
  #
  # @param user [User] The user creating the subscription
  # @param recipient_company [Company, nil] The customer company
  # @param start_date [Date] Subscription start date
  # @param billing_cycle [String] 'monthly', 'quarterly', or 'annual'
  # @param quantity [Decimal] Quantity of units
  # @param unit_price [Decimal] Price per unit
  # @param currency [String] Currency code
  # @param end_date [Date, nil] Optional end date for fixed-term subscriptions
  # @param description [String, nil] Description of the service
  # @return [Subscription] The created subscription
  def self.create_subscription(user:, recipient_company: nil, start_date: Date.current,
                              billing_cycle:, quantity: 1, unit_price:, currency: 'USD',
                              end_date: nil, description: nil, sale_from_company: nil)
    subscription = Subscription.create_with_periods(
      user: user,
      recipient_company: recipient_company,
      sale_from_company: sale_from_company,
      start_date: start_date,
      billing_cycle: billing_cycle,
      quantity: quantity,
      unit_price: unit_price,
      currency: currency,
      description: description,
      end_date: end_date
    )

    subscription.save!
    subscription
  end

  # Add a mid-cycle quantity change to an active subscription
  # This creates a prorated adjustment for the remainder of the current billing period
  #
  # @param subscription [Subscription] The subscription to modify
  # @param quantity_change [Decimal] Change in quantity (positive or negative)
  # @param effective_date [Date] Date the change takes effect
  # @return [Hash] Contains :adjustment_amount, :remaining_days, :prorated_price
  def self.add_mid_cycle_adjustment(subscription:, quantity_change:, effective_date: Date.current)
    raise "Subscription must be active" unless subscription.active_on?(effective_date)
    raise "Effective date must be within current billing period" unless subscription.active_on?(effective_date)

    # Calculate proration for the remainder of the billing period
    full_price = (quantity_change.abs * subscription.unit_price).to_f
    
    remaining_days = (subscription.current_period_end - effective_date).to_i
    cycle_days = (subscription.current_period_end - subscription.current_period_start).to_i
    
    return zero_adjustment if remaining_days <= 0 || cycle_days <= 0

    prorated_ratio = remaining_days.to_f / cycle_days
    prorated_price = full_price * prorated_ratio
    discount_amount = full_price - prorated_price

    adjustment = {
      type: 'mid_cycle_adjustment',
      quantity_change: quantity_change,
      effective_date: effective_date,
      adjustment_amount: prorated_price.round(2),
      discount_amount: discount_amount.round(2),
      remaining_days: remaining_days,
      cycle_days: cycle_days,
      full_price: full_price.round(2)
    }

    # Store adjustment in metadata for tracking
    subscription.metadata ||= {}
    subscription.metadata['adjustments'] ||= []
    subscription.metadata['adjustments'] << adjustment

    subscription.save!
    adjustment
  end

  # Create an invoice from a subscription's current period
  # with optional mid-cycle adjustments
  #
  # @param subscription [Subscription] The subscription to invoice
  # @param adjustments [Array<Hash>, nil] Array of adjustments to include
  # @param invoice_number [String, nil] Optional custom invoice number
  # @return [Invoice] The created invoice
  def self.generate_invoice_from_subscription(subscription:, adjustments: nil, invoice_number: nil)
    raise "Subscription must be due for invoicing" unless subscription.due_for_invoicing?

    invoice = subscription.generate_next_invoice(invoice_number: invoice_number)

    # Apply adjustments if provided
    if adjustments.present?
      apply_adjustments_to_invoice(invoice, adjustments)
    end

    invoice
  end

  # Apply mid-cycle adjustments to an invoice
  #
  # @param invoice [Invoice] The invoice to modify
  # @param adjustments [Array<Hash>] Array of adjustment hashes
  def self.apply_adjustments_to_invoice(invoice, adjustments)
    return if adjustments.blank?

    adjustments.each do |adjustment|
      add_adjustment_line_item(invoice, adjustment)
    end

    invoice.save!
  end

  # Pause a subscription temporarily
  # The subscription won't generate invoices while paused
  #
  # @param subscription [Subscription] The subscription to pause
  def self.pause_subscription(subscription)
    subscription.pause!
  end

  # Resume a paused subscription
  # Resets next_invoice_date to today so it can be invoiced immediately
  #
  # @param subscription [Subscription] The subscription to resume
  def self.resume_subscription(subscription)
    subscription.resume!
  end

  # Cancel a subscription
  # Sets status to 'cancelled' and end_date to today
  #
  # @param subscription [Subscription] The subscription to cancel
  def self.cancel_subscription(subscription)
    subscription.cancel!
  end

  # Extend the end date of a subscription
  #
  # @param subscription [Subscription] The subscription to extend
  # @param new_end_date [Date] The new end date
  def self.extend_subscription(subscription, new_end_date)
    raise "New end date must be after current end date" if subscription.end_date.present? && new_end_date <= subscription.end_date
    raise "New end date must be in the future" if new_end_date <= Date.current

    subscription.update!(end_date: new_end_date, status: 'active')
    subscription
  end

  # Update subscription quantity (for next billing period)
  # Does not apply to current period
  #
  # @param subscription [Subscription] The subscription to update
  # @param new_quantity [Decimal] The new quantity
  def self.update_subscription_quantity(subscription, new_quantity)
    raise "Quantity must be greater than 0" if new_quantity.to_f <= 0

    subscription.update!(quantity: new_quantity)
    subscription
  end

  # Update subscription unit price (for next billing period)
  #
  # @param subscription [Subscription] The subscription to update
  # @param new_unit_price [Decimal] The new unit price
  def self.update_subscription_price(subscription, new_unit_price)
    raise "Unit price must be greater than 0" if new_unit_price.to_f <= 0

    subscription.update!(unit_price: new_unit_price)
    subscription
  end

  private

  def self.zero_adjustment
    {
      adjustment_amount: 0,
      discount_amount: 0,
      remaining_days: 0,
      cycle_days: 0,
      full_price: 0
    }
  end

  def self.add_adjustment_line_item(invoice, adjustment)
    line_items = invoice.line_items_data || []

    adjustment_item = {
      'description' => "Adjustment: #{adjustment[:type]}",
      'quantity' => '1',
      'price' => adjustment[:adjustment_amount].to_s,
      'unit' => 'adjustment',
      'tax_rate' => nil,
      'optional_fields' => {
        'adjustment_details' => {
          'type' => adjustment[:type],
          'effective_date' => adjustment[:effective_date].to_s,
          'full_price' => adjustment[:full_price].to_s,
          'discount_amount' => adjustment[:discount_amount].to_s
        }
      }
    }

    line_items << adjustment_item
    invoice.update_column(:line_items_data, line_items)
  end
end
