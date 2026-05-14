# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :recipient_company, class_name: 'Company', optional: true
  belongs_to :sale_from_company, class_name: 'Company', optional: true
  has_many :invoices, dependent: :restrict_with_error

  enum status: { active: 'active', paused: 'paused', cancelled: 'cancelled', expired: 'expired' }
  enum billing_cycle: { monthly: 'monthly', quarterly: 'quarterly', annual: 'annual' }

  validates :user_id, :start_date, :billing_cycle, :quantity, :unit_price, :currency, presence: true
  validates :quantity, :unit_price, numericality: { greater_than: 0 }
  validates :billing_cycle, inclusion: { in: billing_cycles.keys }
  validate :end_date_after_start_date, if: :end_date_present?
  validate :next_invoice_date_not_in_past, on: :create

  scope :active_on, ->(date = Date.current) {
    where('start_date <= ?', date)
      .where('end_date IS NULL OR end_date > ?', date)
      .where(status: :active)
  }
  scope :due_for_invoicing, ->(date = Date.current) {
    active_on(date).where('next_invoice_date <= ?', date)
  }
  scope :expiring_soon, ->(days_ahead = 7) {
    due_date = Date.current + days_ahead.days
    where(status: :active)
      .where('end_date IS NOT NULL AND end_date <= ?', due_date)
  }

  # Initialize subscription with calculated period dates
  def self.create_with_periods(user:, recipient_company: nil, sale_from_company: nil, 
                               start_date: Date.current, billing_cycle:, 
                               quantity: 1, unit_price:, currency: 'USD', 
                               description: nil, line_item_data: {}, **attrs)
    current_period_end = calculate_next_period(start_date, billing_cycle)
    
    new(
      user: user,
      recipient_company: recipient_company,
      sale_from_company: sale_from_company,
      start_date: start_date,
      current_period_start: start_date,
      current_period_end: current_period_end,
      next_invoice_date: start_date,
      billing_cycle: billing_cycle,
      quantity: quantity,
      unit_price: unit_price,
      currency: currency,
      description: description,
      line_item_data: line_item_data,
      **attrs
    )
  end

  # Calculate the next period end date based on billing cycle
  def self.calculate_next_period(from_date, billing_cycle)
    case billing_cycle
    when 'monthly'
      from_date >> 1
    when 'quarterly'
      from_date >> 3
    when 'annual'
      from_date >> 12
    else
      raise ArgumentError, "Unknown billing cycle: #{billing_cycle}"
    end
  end

  # Check if subscription is currently active
  def active_on?(date = Date.current)
    return false unless active?
    return false if start_date > date
    return false if end_date.present? && end_date <= date
    
    true
  end

  # Check if due for invoice generation
  def due_for_invoicing?(date = Date.current)
    active_on?(date) && next_invoice_date <= date
  end

  # Generate the next invoice for this subscription
  # @param invoice_number [String, nil] Optional invoice number to use
  # @return [Invoice] The newly created invoice
  def generate_next_invoice(invoice_number: nil)
    raise "Cannot generate invoice: subscription not active" unless active_on?
    raise "Cannot generate invoice: subscription not due yet" unless due_for_invoicing?

    # Calculate the next period for the new invoice
    new_period_start = current_period_end
    new_period_end = self.class.calculate_next_period(new_period_start, billing_cycle)

    # Build line items from subscription data
    line_items = build_line_items_for_invoice

    # Create the invoice
    invoice = user.invoices.build(
      recipient_company: recipient_company,
      sale_from: sale_from_company,
      invoice_type: 'sale',
      invoice_category: 'standard',
      issue_date: Date.current,
      invoice_number: invoice_number || Invoice.next_invoice_number_for_user(user, 'sale', 'standard'),
      currency: currency,
      line_items_data: line_items,
      recipient_note: description,
      invoice_info: {
        subscription_id: id,
        billing_period_start: new_period_start,
        billing_period_end: new_period_end
      }
    )

    if invoice.save
      # Update subscription for next cycle
      update_for_renewal(new_period_start, new_period_end)
      invoice
    else
      raise "Failed to generate invoice: #{invoice.errors.full_messages.join(', ')}"
    end
  end

  # Build line items data from subscription
  def build_line_items_for_invoice
    base_item = {
      'description' => description.presence || 'Subscription Service',
      'quantity' => quantity.to_s,
      'price' => unit_price.to_s,
      'unit' => 'service',
      'tax_rate' => nil,
      'optional_fields' => {
        'subscription' => {
          'start_date' => current_period_start.to_s,
          'end_date' => current_period_end.to_s,
          'billing_cycle' => billing_cycle,
          'renewal_date' => current_period_end.to_s
        }
      }
    }

    # Merge with custom line_item_data if present
    if line_item_data.present? && line_item_data.is_a?(Hash)
      base_item.deep_merge(line_item_data)
    else
      [base_item]
    end
  end

  # Update subscription after invoice generation
  def update_for_renewal(new_period_start, new_period_end)
    increment!(:renewal_count)
    update!(
      current_period_start: new_period_start,
      current_period_end: new_period_end,
      next_invoice_date: new_period_start,
      last_invoice_generated_at: Time.current
    )

    # Check if subscription should expire
    if end_date.present? && new_period_start >= end_date
      update_column(:status, 'expired')
    end
  end

  # Pause the subscription
  def pause!
    update!(status: 'paused')
  end

  # Resume a paused subscription
  def resume!
    raise "Cannot resume subscription with end_date in the past" if end_date.present? && end_date <= Date.current
    
    update!(status: 'active', next_invoice_date: Date.current)
  end

  # Cancel the subscription
  def cancel!
    update!(status: 'cancelled', end_date: Date.current)
  end

  # Get the sender company (sale_from or user's company)
  def sender_company
    sale_from_company || user&.company
  end

  # Total estimated annual revenue from this subscription
  def annual_value
    (quantity * unit_price * 12 / cycle_count).round(2)
  end

  # Days until next invoice
  def days_until_next_invoice
    (next_invoice_date - Date.current).to_i
  end

  # Check if end date is approaching (within specified days)
  def expiring_soon?(days_ahead = 7)
    return false if end_date.blank? || !active?
    
    (end_date - Date.current).to_i <= days_ahead
  end

  private

  def cycle_count
    case billing_cycle
    when 'monthly'
      12
    when 'quarterly'
      4
    when 'annual'
      1
    else
      1
    end
  end

  def end_date_after_start_date
    return if end_date.blank?
    
    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def end_date_present?
    end_date.present?
  end

  def next_invoice_date_not_in_past
    return if next_invoice_date.blank?
    
    if next_invoice_date < Date.current
      errors.add(:next_invoice_date, "cannot be in the past")
    end
  end
end
