# frozen_string_literal: true

# Example controller for managing subscriptions
# Add this to your app/controllers/subscriptions_controller.rb

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription_invoice, only: [:show, :cancel, :add_mid_cycle_item]

  # GET /subscriptions
  # List all recurring invoices (subscription contracts) for the current user
  def index
    # We load all invoices that could be parents and filter in ruby since 
    # the recurring elements logic relies on JSON/Ruby parsing.
    all_parent_invoices = current_user.invoices
                                      .includes(:recipient_company)
                                      .where(recurring_parent_invoice_id: nil)
                                      .order(created_at: :desc)
    
    @subscriptions = all_parent_invoices.select(&:subscription_contract?)

    @active_subscriptions = @subscriptions.select { |inv| inv.subscription_active? }
    @finished_subscriptions = @subscriptions.reject { |inv| inv.subscription_active? }
  end

  # GET /subscriptions/:id
  # Show subscription details
  def show
    @invoices = @subscription.recurring_sub_invoices.order(issue_date: :desc).limit(10)
    
    primary_item = @subscription.primary_recurring_item
    if primary_item
      start_d = Date.parse(primary_item[:start_date]) rescue nil
      cycle = primary_item[:cycle] || 'monthly'
      
      if start_d && @subscription.subscription_active?
        current_sequence = @subscription.recurring_sub_invoices.count + 1
        next_date = start_d
        current_sequence.times do
          next_date = @subscription.calculate_next_period_date(next_date, cycle)
        end
        @upcoming_invoice_date = next_date
      end
    end

    @generated_mid_cycle_invoices = current_user.invoices.where(recurring_parent_invoice_id: @subscription.id).where("invoice_number LIKE ?", "%-mid").order(created_at: :desc)

    @mid_cycle_pending_items = []
    if primary_item && primary_item[:start_date]
      primary_date = Date.parse(primary_item[:start_date]) rescue nil
      if primary_date
        @subscription.line_items.each do |item|
          start_d_str = @subscription.extract_subscription_field(item, 'start_date')
          next unless start_d_str
          item_date = Date.parse(start_d_str) rescue nil
          next unless item_date

          if item_date > primary_date
            @mid_cycle_pending_items << {
              item: item,
              expected_generation_date: @upcoming_invoice_date || item_date
            }
          end
        end
      end
    end
  end

  # PATCH /subscriptions/:id/cancel
  # Cancel an active subscription by archiving the parent invoice
  def cancel
    if @subscription.update(archived: true)
      redirect_to subscriptions_path, notice: 'Subscription was successfully cancelled.'
    else
      redirect_to subscriptions_path, alert: 'Unable to cancel subscription.'
    end
  end

  # POST /subscriptions/:id/add_mid_cycle_item
  def add_mid_cycle_item
    item_name = params[:item_name]
    quantity = params[:quantity].to_f
    price = params[:price].to_f
    effective_date_str = params[:effective_date]
    proration = params[:proration]
    charge_type = params[:charge_type]
    memo = params[:memo]
    
    effective_date = Date.parse(effective_date_str) rescue Date.current
    
    primary_item = @subscription.primary_recurring_item
    billing_cycle = primary_item ? (primary_item[:cycle] || 'monthly') : 'monthly'
    
    # Calculate next billing date
    start_d = primary_item ? (Date.parse(primary_item[:start_date]) rescue nil) : Date.current
    if start_d
      current_sequence = @subscription.recurring_sub_invoices.count + 1
      next_date = start_d
      current_sequence.times do
        next_date = @subscription.calculate_next_period_date(next_date, billing_cycle)
      end
    else
      next_date = effective_date >> 1
    end
    
    amount_to_charge = 0.0
    
    if proration == 'prorate'
      days_remaining = (next_date - effective_date).to_i
      days_remaining = 0 if days_remaining < 0
      
      months = case billing_cycle
               when 'monthly' then 1
               when 'quarterly' then 3
               when 'annual' then 12
               else 1
               end
      cycle_start_date = next_date << months
      total_days = (next_date - cycle_start_date).to_i
      total_days = 30 if total_days <= 0
      
      proration_ratio = days_remaining.to_f / total_days.to_f
      proration_ratio = 1.0 if proration_ratio > 1.0
      
      amount_to_charge = price * proration_ratio
    elsif proration == 'full'
      amount_to_charge = price
    end
    
    if ['prorate', 'full'].include?(proration) && amount_to_charge > 0
      prorated_item = {
        'description' => "Mid-cycle charge: #{item_name}#{memo.present? ? ' - ' + memo : ''}",
        'quantity' => quantity.to_s,
        'price' => ('%.2f' % amount_to_charge),
        'unit' => 'service',
        'tax' => '0',
        'optional_fields' => {
          'one_time_charge' => true,
          'target_date' => next_date.to_s,
          'billed' => false,
          'hidden_on_parent' => true
        }
      }
      @subscription.add_subscription_item!(prorated_item)
    end
    
    if charge_type == 'recurring'
      new_item = {
        'description' => "#{item_name}#{memo.present? ? ' - ' + memo : ''}",
        'quantity' => quantity.to_s,
        'price' => price.to_s,
        'unit' => 'service',
        'tax' => '0',
        'optional_fields' => {
          'subscription' => {
            'start_date' => effective_date.to_s,
            'billing_cycle' => billing_cycle
          },
          'hidden_on_parent' => true
        }
      }
      @subscription.add_subscription_item!(new_item)
    end
    
    redirect_to subscription_path(@subscription), notice: 'Mid-cycle subscription item added to the next invoice successfully.'
  end

  private

  def generate_immediate_invoice(item_name, quantity, amount_to_charge, memo)
    sub_invoice_number = Invoice.next_recurring_sub_invoice_number(@subscription) + "-mid"
    
    item = {
      'description' => "Mid-cycle: #{item_name}#{memo.present? ? ' - ' + memo : ''}",
      'quantity' => quantity.to_s,
      'price' => ('%.2f' % amount_to_charge),
      'unit' => 'service',
      'tax' => '0'
    }
    
    total_val = quantity * amount_to_charge
    
    new_invoice = current_user.invoices.build(
      recipient_company: @subscription.recipient_company,
      sale_from: @subscription.sale_from,
      invoice_type: @subscription.invoice_type,
      invoice_category: @subscription.invoice_category,
      issue_date: Date.current,
      invoice_number: sub_invoice_number,
      currency: @subscription.currency,
      line_items_data: [item],
      recipient_note: memo,
      billing_reference: @subscription.invoice_number,
      recurring_parent_invoice_id: @subscription.id,
      total: {
        "subtotal" => ('%.2f' % total_val),
        "grand_total" => ('%.2f' % total_val),
        "charge" => ('%.2f' % total_val)
      }
    )
    new_invoice.save!
  end

  def set_subscription_invoice
    @subscription = current_user.invoices.find(params[:id])
    unless @subscription.subscription_contract?
      redirect_to subscriptions_path, alert: 'Not a valid subscription.'
    end
  end
end
