# frozen_string_literal: true

# Example controller for managing subscriptions
# Add this to your app/controllers/subscriptions_controller.rb

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription_invoice, only: [:show, :cancel, :add_mid_cycle_item, :cancel_item]

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
    @cancelled_subscriptions = @subscriptions.select { |inv| inv.subscription_cancelled? }
    @finished_subscriptions = @subscriptions.select { |inv| inv.subscription_finished? }
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
    @mid_cycle_generated_items = []
    if primary_item && primary_item[:start_date]
      primary_date = Date.parse(primary_item[:start_date]) rescue nil
      if primary_date
        latest_billed_date = primary_date
        @subscription.recurring_sub_invoices.count.times do
          latest_billed_date = @subscription.calculate_next_period_date(latest_billed_date, primary_item[:cycle] || 'monthly')
        end

        primary_item_index = (@subscription.line_items_data || []).index do |i|
          i.is_a?(Hash) && i['optional_fields'].is_a?(Hash) && i['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
        end

        (@subscription.line_items_data || []).each_with_index do |item, index|
          next unless item.is_a?(Hash)
          next if index == primary_item_index
          
          optional_fields = item['optional_fields'] || {}
          
          if optional_fields['one_time_charge']
            target_date = Date.parse(optional_fields['target_date']) rescue nil
            if !optional_fields['billed']
              @mid_cycle_pending_items << {
                item: item,
                index: index,
                expected_generation_date: target_date || @upcoming_invoice_date,
                effective_date: target_date || @upcoming_invoice_date,
                billing_cycle: 'One-time'
              }
            else
              @mid_cycle_generated_items << {
                item: item,
                index: index,
                generation_date: target_date || @upcoming_invoice_date,
                effective_date: target_date || @upcoming_invoice_date,
                billing_cycle: 'One-time'
              }
            end
          else
            start_d_str = @subscription.extract_subscription_field(item, 'start_date')
            next unless start_d_str
            item_date = Date.parse(start_d_str) rescue nil
            next unless item_date
            
            item_billing_cycle = @subscription.extract_subscription_field(item, 'billing_cycle') || 'Monthly'

            is_pending = false
            if item_date > latest_billed_date
              is_pending = true
            elsif item_date == latest_billed_date && optional_fields['hidden_on_parent']
              is_pending = true
            end

            if is_pending
              @mid_cycle_pending_items << {
                item: item,
                index: index,
                expected_generation_date: @upcoming_invoice_date || item_date,
                effective_date: item_date,
                billing_cycle: item_billing_cycle.capitalize
              }
            else
              @mid_cycle_generated_items << {
                item: item,
                index: index,
                generation_date: item_date,
                effective_date: item_date,
                billing_cycle: item_billing_cycle.capitalize
              }
            end
          end
          
          if optional_fields['cancellation']
            cancellation_date = Date.parse(optional_fields['effective_date']) rescue Date.current
            @mid_cycle_generated_items << {
              item: item,
              index: index,
              generation_date: cancellation_date,
              effective_date: cancellation_date,
              billing_cycle: 'Cancellation',
              is_cancellation: true
            }
          end
        end
      end
    end
  end

  # PATCH /subscriptions/:id/cancel
  # Cancel an active subscription by archiving the parent invoice
  def cancel
    effective_date_str = params[:effective_date]
    billing_option = params[:billing_option] || 'none'
    reason = params[:reason]
    
    effective_date = Date.parse(effective_date_str) rescue Date.current
    primary_item = @subscription.primary_recurring_item
    
    if ['prorate', 'full'].include?(billing_option) && primary_item
      billing_cycle = primary_item[:cycle] || 'monthly'
      start_d = Date.parse(primary_item[:start_date]) rescue Date.current
      
      current_sequence = @subscription.recurring_sub_invoices.count + 1
      next_date = start_d
      current_sequence.times do
        next_date = @subscription.calculate_next_period_date(next_date, billing_cycle)
      end
      
      # Determine base price by summing all recurring item prices
      recurring_price = @subscription.line_items_data.select do |item|
        item.is_a?(Hash) && item.dig('optional_fields', 'subscription').present? && !item.dig('optional_fields', 'hidden_on_parent')
      end.sum { |item| (item['price'].to_f * (item['quantity'] || 1).to_f) }
      
      amount_to_charge = 0.0
      
      if billing_option == 'prorate'
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
        
        amount_to_charge = recurring_price * proration_ratio
      elsif billing_option == 'full'
        amount_to_charge = recurring_price
      end
      
      if amount_to_charge > 0
        desc = "Final Invoice - #{billing_option == 'prorate' ? 'Prorated' : 'Full'} Charge"
        generate_immediate_invoice(desc, 1, amount_to_charge, reason)
      end
    end
    
    cancellation_item = {
      'description' => "Subscription Cancelled#{reason.present? ? ' - ' + reason : ''}",
      'quantity' => '1',
      'price' => '0.00',
      'unit' => 'service',
      'tax' => '0',
      'optional_fields' => {
        'cancellation' => true,
        'effective_date' => effective_date.to_s,
        'billing_option' => billing_option,
        'hidden_on_parent' => true
      }
    }
    @subscription.add_subscription_item!(cancellation_item)
    
    has_custom_items = @subscription.line_items_data.any? do |item|
      item.is_a?(Hash) &&
        item.dig('optional_fields', 'subscription').blank? &&
        item.dig('optional_fields', 'cancellation').blank?
    end

    if has_custom_items
      if @subscription.save
        redirect_to subscription_path(@subscription), notice: 'Subscription was successfully cancelled.'
      else
        redirect_to subscription_path(@subscription), alert: 'Unable to cancel subscription.'
      end
    else
      if @subscription.update(archived: true)
        redirect_to subscription_path(@subscription), notice: 'Subscription was successfully cancelled.'
      else
        redirect_to subscription_path(@subscription), alert: 'Unable to cancel subscription.'
      end
    end
  end

  # PATCH /subscriptions/:id/cancel_item
  def cancel_item
    item_index = params[:item_index].to_i
    effective_date_str = params[:effective_date]
    billing_option = params[:billing_option] || 'none'
    reason = params[:reason]
    
    effective_date = Date.parse(effective_date_str) rescue Date.current
    
    line_items = @subscription.line_items_data || []
    item = line_items[item_index]
    
    if item.blank? || !item.is_a?(Hash)
      redirect_to subscription_path(@subscription), alert: 'Item not found.'
      return
    end

    billing_cycle = @subscription.extract_subscription_field(item, 'billing_cycle') || 'monthly'
    start_d_str = @subscription.extract_subscription_field(item, 'start_date')
    start_d = start_d_str.present? ? (Date.parse(start_d_str) rescue Date.current) : Date.current
    
    if ['prorate', 'full'].include?(billing_option)
      current_sequence = @subscription.recurring_sub_invoices.count + 1
      next_date = start_d
      current_sequence.times do
        next_date = @subscription.calculate_next_period_date(next_date, billing_cycle)
      end
      
      item_price = (item['price'].to_f * (item['quantity'] || 1).to_f)
      amount_to_charge = 0.0
      
      if billing_option == 'prorate'
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
        
        amount_to_charge = item_price * proration_ratio
      elsif billing_option == 'full'
        amount_to_charge = item_price
      end
      
      if amount_to_charge > 0
        desc = "Final Invoice (#{item['description']}) - #{billing_option == 'prorate' ? 'Prorated' : 'Full'} Charge"
        generate_immediate_invoice(desc, 1, amount_to_charge, reason)
      end
    end
    
    # Mark the original item as cancelled
    item['optional_fields'] ||= {}
    item['optional_fields']['cancelled'] = true
    
    cancellation_item = {
      'description' => "Item Cancelled: #{item['description']}#{reason.present? ? ' - ' + reason : ''}",
      'quantity' => '1',
      'price' => '0.00',
      'unit' => 'service',
      'tax' => '0',
      'optional_fields' => {
        'cancellation' => true,
        'effective_date' => effective_date.to_s,
        'billing_option' => billing_option,
        'hidden_on_parent' => true
      }
    }
    
    line_items << cancellation_item
    
    if @subscription.update(line_items_data: line_items)
      redirect_to subscription_path(@subscription), notice: 'Mid-cycle item was successfully cancelled.'
    else
      redirect_to subscription_path(@subscription), alert: 'Unable to cancel item.'
    end
  end

  # POST /subscriptions/:id/add_mid_cycle_item
  def add_mid_cycle_item
    item_name = params[:item_name]
    item_type = params[:item_type] || 'charge'
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
      is_exact_start = (@subscription.issue_date == effective_date)
      
      unless charge_type == 'recurring' && is_exact_start
      final_amount = item_type == 'discount' ? -amount_to_charge : amount_to_charge
      desc_prefix = item_type == 'discount' ? "Mid-cycle discount" : "Mid-cycle charge"
      
      prorated_item = {
        'description' => "#{desc_prefix}: #{item_name}#{memo.present? ? ' - ' + memo : ''}",
        'quantity' => quantity.to_s,
        'price' => ('%.2f' % final_amount),
        'unit' => 'service',
        'tax' => '0',
        'optional_fields' => {
          'one_time_charge' => true,
          'target_date' => next_date.to_s,
          'billed' => false,
          'hidden_on_parent' => (@subscription.issue_date != effective_date)
        }
      }
      @subscription.add_subscription_item!(prorated_item)
      end
    end
    
    if charge_type == 'recurring'
      final_price = item_type == 'discount' ? -price : price
      desc_suffix = item_type == 'discount' ? " (Discount)" : ""
      
      new_item = {
        'description' => "#{item_name}#{memo.present? ? ' - ' + memo : ''}#{desc_suffix}",
        'quantity' => quantity.to_s,
        'price' => final_price.to_s,
        'unit' => 'service',
        'tax' => '0',
        'optional_fields' => {
          'subscription' => {
            'start_date' => effective_date.to_s,
            'end_date' => primary_item && primary_item[:end_date].present? ? primary_item[:end_date] : nil,
            'billing_cycle' => billing_cycle
          }.compact,
          'hidden_on_parent' => ((@subscription.issue_date != effective_date) || proration == 'next')
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
