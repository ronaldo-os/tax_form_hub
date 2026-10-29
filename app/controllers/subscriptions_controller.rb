# frozen_string_literal: true

# Example controller for managing subscriptions
# Add this to your app/controllers/subscriptions_controller.rb

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription_invoice, only: [:show, :cancel, :add_mid_cycle_item, :cancel_item, :retry_invoicing]
  before_action -> { store_back_url(:subscription_back_url) }, only: [:show]

  # GET /subscriptions
  # List all recurring invoices (subscription contracts) for the current user
  def index
    # We load all invoices that could be parents and filter in ruby since 
    # the recurring elements logic relies on JSON/Ruby parsing.
    all_parent_invoices = current_user.invoices
                                      .includes(:recipient_company, :sale_from)
                                      .where(recurring_parent_invoice_id: nil)
                                      .order(created_at: :desc)
    
    # Partition parent invoices by invoice_type
    sales_parent_invoices = all_parent_invoices.select { |inv| inv.invoice_type == 'sale' }
    purchase_parent_invoices = all_parent_invoices.select { |inv| inv.invoice_type == 'purchase' }

    # Extract subscription items for sales
    @sales_subscriptions = extract_subscription_wrappers(sales_parent_invoices.select(&:subscription_contract?))
    @active_sales_subscriptions = @sales_subscriptions.select(&:subscription_active?)
    @finished_sales_subscriptions = @sales_subscriptions.select(&:subscription_finished?)
    @cancelled_sales_subscriptions = @sales_subscriptions.select(&:subscription_cancelled?)

    # Extract subscription items for purchases
    @purchase_subscriptions = extract_subscription_wrappers(purchase_parent_invoices.select(&:subscription_contract?))
    @active_purchase_subscriptions = @purchase_subscriptions.select(&:subscription_active?)
    @finished_purchase_subscriptions = @purchase_subscriptions.select(&:subscription_finished?)
    @cancelled_purchase_subscriptions = @purchase_subscriptions.select(&:subscription_cancelled?)

    # Extract price adjustments for sales
    @sales_price_adjustments = extract_price_adjustment_wrappers(sales_parent_invoices)
    @active_sales_price_adjustments = @sales_price_adjustments.select(&:subscription_active?)
    @finished_sales_price_adjustments = @sales_price_adjustments.select(&:subscription_finished?)
    @cancelled_sales_price_adjustments = @sales_price_adjustments.select(&:subscription_cancelled?)

    # Extract price adjustments for purchases
    @purchase_price_adjustments = extract_price_adjustment_wrappers(purchase_parent_invoices)
    @active_purchase_price_adjustments = @purchase_price_adjustments.select(&:subscription_active?)
    @finished_purchase_price_adjustments = @purchase_price_adjustments.select(&:subscription_finished?)
    @cancelled_purchase_price_adjustments = @purchase_price_adjustments.select(&:subscription_cancelled?)

    # Active tab and inner status parameters (defaults to 'sales' and 'active')
    @active_tab = %w[sales purchases].include?(params[:tab]) ? params[:tab] : 'sales'
    raw_status = (params[:status].presence || params[:subtab].presence).to_s.downcase
    @active_status = %w[active finished cancelled].include?(raw_status) ? raw_status : 'active'
    raw_pa_status = params[:pa_status].to_s.downcase
    @active_pa_status = %w[active finished cancelled].include?(raw_pa_status) ? raw_pa_status : 'active'

    # Backward compatibility
    @subscriptions = @sales_subscriptions + @purchase_subscriptions
    @active_subscriptions = @active_sales_subscriptions + @active_purchase_subscriptions
    @finished_subscriptions = @finished_sales_subscriptions + @finished_purchase_subscriptions
    @cancelled_subscriptions = @cancelled_sales_subscriptions + @cancelled_purchase_subscriptions
    @price_adjustments = @sales_price_adjustments + @purchase_price_adjustments
    @active_price_adjustments = @active_sales_price_adjustments + @active_purchase_price_adjustments
    @finished_price_adjustments = @finished_sales_price_adjustments + @finished_purchase_price_adjustments
    @cancelled_price_adjustments = @cancelled_sales_price_adjustments + @cancelled_purchase_price_adjustments
  end

  # GET /subscriptions/:id
  # Show subscription details
  def show
    @invoices = @subscription.recurring_sub_invoices.order(issue_date: :desc).limit(10)
    
    first_sub_index = (@subscription.line_items_data || []).index do |i|
      i.is_a?(Hash) && i['optional_fields'].is_a?(Hash) && i['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') } && !i.dig('optional_fields', 'hidden_on_parent')
    end

    @item_index = params[:item_index].present? ? params[:item_index].to_i : first_sub_index

    primary_line_item = @item_index ? @subscription.line_items_data[@item_index] : nil
    primary_item = nil
    if primary_line_item
      primary_item = {
        description: primary_line_item['description'],
        cycle: @subscription.extract_subscription_field(primary_line_item, 'billing_cycle') || 'monthly',
        start_date: @subscription.extract_subscription_field(primary_line_item, 'start_date'),
        end_date: @subscription.extract_subscription_field(primary_line_item, 'end_date')
      }
    end

    if primary_item
      start_d = Date.parse(primary_item[:start_date]) rescue nil
      cycle = primary_item[:cycle] || 'monthly'
      
      @wrapper = SubscriptionItemWrapper.new(@subscription, primary_line_item, @item_index)
      
      if start_d && @wrapper.subscription_active?
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

        (@subscription.line_items_data || []).each_with_index do |item, index|
          next unless item.is_a?(Hash)
          next if index == @item_index
          
          optional_fields = item['optional_fields'] || {}
          
          # Skip other main subscriptions that don't have hidden_on_parent
          is_another_main_subscription = optional_fields['subscription'].present? && !optional_fields['hidden_on_parent']
          next if is_another_main_subscription
          
          # Filter by parent_item_index
          parent_idx = optional_fields['parent_item_index']
          expected_parent_idx = parent_idx.present? ? parent_idx.to_i : first_sub_index
          next unless expected_parent_idx == @item_index
          
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

  # POST /subscriptions/:id/retry_invoicing
  # Manually retry or trigger recurring invoice generation for a subscription contract
  def retry_invoicing
    begin
      invoices = @subscription.generate_subscription_invoices(Date.current)
      if invoices.any?
        if @subscription.invoice_info.is_a?(Hash) && @subscription.invoice_info['recurring_generation_error'].present?
          new_info = @subscription.invoice_info.except('recurring_generation_error')
          @subscription.update_column(:invoice_info, new_info)
        end
        redirect_to subscription_path(@subscription), notice: "Successfully generated #{invoices.size} recurring invoice(s)."
      else
        redirect_to subscription_path(@subscription), notice: "No recurring invoices were due for generation at this time."
      end
    rescue StandardError => e
      error_data = {
        'message' => e.message,
        'failed_at' => Time.current.iso8601,
        'attempted_date' => Date.current.to_s
      }
      new_info = (@subscription.invoice_info || {}).merge('recurring_generation_error' => error_data)
      @subscription.update_column(:invoice_info, new_info)
      redirect_to subscription_path(@subscription), alert: "Failed to generate recurring invoice: #{e.message}"
    end
  end

  # PATCH /subscriptions/:id/cancel
  # Cancel an active subscription by archiving the parent invoice
  def cancel
    effective_date_str = params[:effective_date]
    billing_option = params[:billing_option] || 'none'
    reason = params[:reason]
    effective_date = Date.parse(effective_date_str) rescue Date.current
    item_index = params[:item_index].presence ? params[:item_index].to_i : nil
    item_type = params[:item_type]

    is_price_adjustment = item_type == 'Price Adjustment' || (!@subscription.has_subscription_line_items? && @subscription.has_recurring_price_adjustments?)
    redirect_path = params[:redirect_to].presence || (is_price_adjustment ? price_adjustment_path(@subscription) : subscription_path(@subscription))
    notice_msg = is_price_adjustment ? 'Price adjustment was successfully cancelled.' : 'Subscription was successfully cancelled.'
    alert_msg = is_price_adjustment ? 'Unable to cancel price adjustment.' : 'Unable to cancel subscription.'

    if perform_subscription_cancellation(@subscription, item_index: item_index, item_type: item_type, effective_date: effective_date, billing_option: billing_option, reason: reason)
      redirect_to redirect_path, notice: notice_msg
    else
      redirect_to redirect_path, alert: alert_msg
    end
  rescue StandardError => e
    Rails.logger.error("Failed to cancel subscription #{@subscription.id}: #{e.message}")
    redirect_to redirect_path, alert: alert_msg
  end

  # POST /subscriptions/bulk_action
  def bulk_action
    action_type = params[:bulk_action].to_s
    raw_ids = Array(params[:subscription_ids].presence || params[:ids])
    subscription_ids = raw_ids.map do |raw_id|
      raw_id.to_s.split(':').first.to_i
    end.reject(&:zero?).uniq

    tab = params[:tab].presence || "sales"

    if subscription_ids.empty?
      redirect_to subscriptions_path(tab: tab), status: :see_other, alert: "No subscriptions selected."
      return
    end

    # Authorization: strictly scope to current_user
    subscriptions = current_user.invoices.where(id: subscription_ids).select(&:subscription_contract?)

    if subscriptions.empty?
      redirect_to subscriptions_path(tab: tab), status: :see_other, alert: "No authorized subscriptions found to perform this action."
      return
    end

    case action_type
    when "cancel", "cancel_subscription"
      effective_date = Date.parse(params[:effective_date].to_s) rescue Date.current
      billing_option = params[:billing_option].presence || "none"
      reason = params[:reason].presence
      item_type = params[:item_type]

      cancelled_count = 0
      skipped_count = 0

      items_by_sub_id = Hash.new { |h, k| h[k] = [] }
      raw_ids.each do |raw_id|
        parts = raw_id.to_s.split(':')
        s_id = parts.first.to_i
        next if s_id.zero?
        idx = parts.size > 1 ? parts.last.to_i : nil
        items_by_sub_id[s_id] << idx
      end

      items_by_sub_id.each do |sub_id, indices|
        sub = subscriptions.find { |s| s.id == sub_id }
        unless sub
          skipped_count += [indices.size, 1].max
          next
        end

        indices = [nil] if indices.empty?

        indices.each do |idx|
          sub.reload if sub.persisted?

          is_item_active = if item_type == 'Price Adjustment' || (!sub.has_subscription_line_items? && sub.has_recurring_price_adjustments?)
                             if idx && sub.price_adjustments.is_a?(Array) && sub.price_adjustments[idx].is_a?(Hash)
                               adj = sub.price_adjustments[idx]
                               !adj['cancelled'] && !adj[:cancelled]
                             else
                               sub.subscription_active?
                             end
                           else
                             if idx && sub.line_items_data.is_a?(Array) && sub.line_items_data[idx].is_a?(Hash)
                               item = sub.line_items_data[idx]
                               !item.dig('optional_fields', 'cancelled')
                             else
                               sub.subscription_active?
                             end
                           end

          unless is_item_active
            skipped_count += 1
            next
          end

          begin
            perform_subscription_cancellation(
              sub,
              item_index: idx,
              item_type: item_type,
              effective_date: effective_date,
              billing_option: billing_option,
              reason: reason
            )
            cancelled_count += 1
          rescue StandardError => e
            Rails.logger.error("Failed to bulk cancel subscription #{sub.id} (item #{idx}): #{e.message}")
            skipped_count += 1
          end
        end
      end

      item_type_label = if item_type.to_s.downcase.include?('price adjustment') || subscriptions.all? { |s| s.has_recurring_price_adjustments? && !s.has_subscription_line_items? }
                          "price adjustment"
                        elsif subscriptions.all?(&:has_subscription_line_items?)
                          "subscription"
                        else
                          "item"
                        end

      if cancelled_count > 0 && skipped_count > 0
        notice = "Successfully cancelled #{cancelled_count} #{item_type_label.pluralize(cancelled_count)}. #{skipped_count} #{item_type_label.pluralize(skipped_count)} skipped (already finished, cancelled, or encountered an error)."
        respond_to do |format|
          format.html { redirect_to subscriptions_path(tab: tab), status: :see_other, notice: notice }
          format.json { render json: { notice: notice, cancelled_count: cancelled_count, skipped_count: skipped_count }, status: :ok }
        end
      elsif cancelled_count > 0
        notice = "Successfully cancelled #{cancelled_count} #{item_type_label.pluralize(cancelled_count)}."
        respond_to do |format|
          format.html { redirect_to subscriptions_path(tab: tab), status: :see_other, notice: notice }
          format.json { render json: { notice: notice, cancelled_count: cancelled_count }, status: :ok }
        end
      else
        alert = "Could not cancel the selected #{item_type_label.pluralize}."
        respond_to do |format|
          format.html { redirect_to subscriptions_path(tab: tab), status: :see_other, alert: alert }
          format.json { render json: { alert: alert }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to subscriptions_path(tab: tab), status: :see_other, alert: "Invalid action." }
        format.json { render json: { alert: "Invalid action." }, status: :unprocessable_entity }
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
    
    if ['prorate', 'full'].include?(billing_option) && @subscription.sale?
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
      redirect_to subscription_path(@subscription, item_index: item_index), notice: 'Mid-cycle item was successfully cancelled.'
    else
      redirect_to subscription_path(@subscription, item_index: item_index), alert: 'Unable to cancel item.'
    end
  end

  # POST /subscriptions/:id/add_mid_cycle_item
  def add_mid_cycle_item
    if @subscription.purchase?
      redirect_to subscription_path(@subscription), alert: 'Mid-cycle items can only be added to sales subscriptions.'
      return
    end

    item_name = params[:item_name]
    item_type = params[:item_type] || 'charge'
    quantity = params[:quantity].to_s.delete(',').to_f
    price = params[:price].to_s.delete(',').to_f
    effective_date_str = params[:effective_date]
    proration = params[:proration]
    charge_type = params[:charge_type]
    memo = params[:memo]
    
    effective_date = Date.parse(effective_date_str) rescue Date.current
    
    item_index = params[:parent_item_index].present? ? params[:parent_item_index].to_i : nil
    primary_line_item = item_index ? @subscription.line_items_data[item_index] : nil
    
    if primary_line_item
      primary_item = {
        cycle: @subscription.extract_subscription_field(primary_line_item, 'billing_cycle') || 'monthly',
        start_date: @subscription.extract_subscription_field(primary_line_item, 'start_date'),
        end_date: @subscription.extract_subscription_field(primary_line_item, 'end_date')
      }
    else
      primary_item = @subscription.primary_recurring_item
    end
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
          'hidden_on_parent' => (@subscription.issue_date != effective_date),
          'parent_item_index' => params[:parent_item_index]
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
          'hidden_on_parent' => ((@subscription.issue_date != effective_date) || proration == 'next'),
          'parent_item_index' => params[:parent_item_index]
        }
      }
      @subscription.add_subscription_item!(new_item)
    end
    
    redirect_to subscription_path(@subscription, item_index: params[:parent_item_index]), notice: 'Mid-cycle subscription item added to the next invoice successfully.'
  end

  private

  def extract_subscription_wrappers(invoices)
    wrappers = []
    invoices.each do |invoice|
      if invoice.line_items_data.is_a?(Array)
        invoice.line_items_data.each_with_index do |item, idx|
          if item.is_a?(Hash) && item['optional_fields'].is_a?(Hash) && item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
            wrappers << SubscriptionItemWrapper.new(invoice, item, idx)
          end
        end
      end
    end
    wrappers
  end

  def extract_price_adjustment_wrappers(invoices)
    wrappers = []
    invoices.each do |invoice|
      if invoice.price_adjustments.is_a?(Array)
        invoice.price_adjustments.each_with_index do |adj, idx|
          next unless adj.is_a?(Hash)
          freq = adj['frequency'] || adj[:frequency] || (adj['unit'] == 'monthly_charge' || adj[:unit] == 'monthly_charge' ? 'monthly' : nil)
          if %w[monthly annually yearly].include?(freq.to_s)
            wrappers << PriceAdjustmentItemWrapper.new(invoice, adj, idx)
          end
        end
      end
    end
    wrappers
  end

  def generate_immediate_invoice(item_name, quantity, amount_to_charge, memo, subscription = @subscription)
    sub_invoice_number = Invoice.next_recurring_sub_invoice_number(subscription) + "-mid"
    
    item = {
      'description' => "Mid-cycle: #{item_name}#{memo.present? ? ' - ' + memo : ''}",
      'quantity' => quantity.to_s,
      'price' => ('%.2f' % amount_to_charge),
      'unit' => 'service',
      'tax' => '0'
    }
    
    total_val = quantity * amount_to_charge
    
    new_invoice = current_user.invoices.build(
      recipient_company: subscription.recipient_company,
      sale_from: subscription.sale_from,
      invoice_type: subscription.invoice_type,
      invoice_category: subscription.invoice_category,
      issue_date: Date.current,
      invoice_number: sub_invoice_number,
      currency: subscription.currency,
      line_items_data: [item],
      recipient_note: memo,
      billing_reference: subscription.invoice_number,
      recurring_parent_invoice_id: subscription.id,
      total: {
        "subtotal" => ('%.2f' % total_val),
        "grand_total" => ('%.2f' % total_val),
        "charge" => ('%.2f' % total_val)
      }
    )
    new_invoice.save!
    if new_invoice.attachments.attached?
      ActiveStorage::Attachment.where(record_type: 'Invoice', record_id: new_invoice.id).delete_all
      new_invoice.attachments.reset
    end
  end

  def perform_subscription_cancellation(subscription, item_index: nil, item_type: nil, effective_date: Date.current, billing_option: 'none', reason: nil)
    is_pa = item_type == 'Price Adjustment' || (!subscription.has_subscription_line_items? && subscription.has_recurring_price_adjustments?)
    
    # 1. Final Invoice Billing Option: Prorate or Full charge for sales
    if ['prorate', 'full'].include?(billing_option) && subscription.sale?
      target_item = nil
      cycle = 'monthly'
      start_d = Date.current
      recurring_price = 0.0

      if is_pa && subscription.price_adjustments.is_a?(Array)
        adj = (item_index && subscription.price_adjustments[item_index].is_a?(Hash)) ? subscription.price_adjustments[item_index] : subscription.recurring_price_adjustments.first
        if adj
          target_item = adj
          freq = adj['frequency'] || adj[:frequency] || (adj['unit'] == 'monthly_charge' ? 'monthly' : nil)
          cycle = case freq.to_s
                  when 'annually', 'yearly' then 'annual'
                  when 'quarterly' then 'quarterly'
                  else 'monthly'
                  end
          start_d = (Date.parse(adj['charge_start_date'].to_s) rescue Date.current) || Date.current
          recurring_price = adj['amount'].to_f
        end
      else
        lines = subscription.line_items_data || []
        item = (item_index && lines[item_index].is_a?(Hash)) ? lines[item_index] : nil
        if item
          target_item = item
          cycle = subscription.extract_subscription_field(item, 'billing_cycle') || 'monthly'
          start_d_str = subscription.extract_subscription_field(item, 'start_date')
          start_d = (Date.parse(start_d_str) rescue Date.current) || Date.current
          recurring_price = item['price'].to_f * (item['quantity'] || 1).to_f
        else
          primary_item = subscription.primary_recurring_item
          if primary_item
            target_item = primary_item
            cycle = primary_item[:cycle] || 'monthly'
            start_d = (Date.parse(primary_item[:start_date].to_s) rescue Date.current) || Date.current
            recurring_price = (subscription.line_items_data || []).select do |l|
              l.is_a?(Hash) && l.dig('optional_fields', 'subscription').present? && !l.dig('optional_fields', 'hidden_on_parent')
            end.sum { |l| l['price'].to_f * (l['quantity'] || 1).to_f }
          end
        end
      end

      if target_item && recurring_price > 0
        current_sequence = subscription.recurring_sub_invoices.count + 1
        next_date = start_d
        current_sequence.times do
          next_date = subscription.calculate_next_period_date(next_date, cycle)
        end

        amount_to_charge = 0.0
        if billing_option == 'prorate'
          days_remaining = (next_date - effective_date).to_i
          days_remaining = 0 if days_remaining < 0

          months = case cycle
                   when 'monthly' then 1
                   when 'quarterly' then 3
                   when 'annual' then 12
                   else 1
                   end
          cycle_start_date = next_date << months
          total_days = (next_date - cycle_start_date).to_i
          total_days = 30 if total_days <= 0

          proration_ratio = [days_remaining.to_f / total_days.to_f, 1.0].min
          amount_to_charge = recurring_price * proration_ratio
        elsif billing_option == 'full'
          amount_to_charge = recurring_price
        end

        if amount_to_charge > 0
          desc_title = if is_pa
                         (target_item.is_a?(Hash) && (target_item['description_edit'].presence || target_item['description'].presence)) || "Price Adjustment"
                       else
                         (target_item.is_a?(Hash) && target_item['description'].presence) || "Subscription"
                       end
          desc = "Final Invoice (#{desc_title}) - #{billing_option == 'prorate' ? 'Prorated' : 'Full'} Charge"
          generate_immediate_invoice(desc, 1, amount_to_charge, reason, subscription)
        end
      end
    end

    # 2. Add cancellation line item and mark line items / price adjustments cancelled
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

    lines = subscription.line_items_data || []
    if is_pa && subscription.price_adjustments.is_a?(Array)
      adjs = subscription.price_adjustments.deep_dup
      if item_index && adjs[item_index].is_a?(Hash)
        adjs[item_index]['cancelled'] = true
      else
        adjs.each do |adj|
          if adj.is_a?(Hash)
            freq = adj['frequency'] || adj[:frequency] || (adj['unit'] == 'monthly_charge' ? 'monthly' : nil)
            adj['cancelled'] = true if %w[monthly annually yearly].include?(freq.to_s)
          end
        end
      end
      subscription.price_adjustments = adjs
    else
      if item_index && lines[item_index].is_a?(Hash)
        lines[item_index]['optional_fields'] ||= {}
        lines[item_index]['optional_fields']['cancelled'] = true
      else
        lines.each do |l_item|
          if l_item.is_a?(Hash) && l_item['optional_fields'].is_a?(Hash) && l_item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
            l_item['optional_fields']['cancelled'] = true
          end
        end
      end
      subscription.line_items_data = lines
    end

    subscription.add_subscription_item!(cancellation_item)

    # 3. Check whether to archive or keep active
    has_custom_items = (subscription.line_items_data || []).any? do |item|
      item.is_a?(Hash) &&
        item.dig('optional_fields', 'subscription').blank? &&
        item.dig('optional_fields', 'cancellation').blank?
    end

    has_other_active_subscriptions = (subscription.line_items_data || []).any? do |item|
      item.is_a?(Hash) &&
        item.dig('optional_fields', 'subscription').present? &&
        !item.dig('optional_fields', 'cancelled') &&
        !item.dig('optional_fields', 'hidden_on_parent')
    end

    has_other_active_price_adjustments = (subscription.price_adjustments || []).any? do |adj|
      next false unless adj.is_a?(Hash)
      next false if adj['cancelled'] || adj[:cancelled]
      freq = adj['frequency'] || adj[:frequency] || (adj['unit'] == 'monthly_charge' ? 'monthly' : nil)
      next false unless %w[monthly annually yearly].include?(freq.to_s)
      end_d = Date.parse(adj['charge_end_date'].to_s) rescue nil if adj['charge_end_date'].present?
      end_d.nil? || end_d >= Date.current
    end

    if has_custom_items || has_other_active_subscriptions || has_other_active_price_adjustments
      subscription.save!
    else
      subscription.update!(archived: true)
    end
    true
  end

  def set_subscription_invoice
    @subscription = current_user.invoices.find(params[:id])
    unless @subscription.subscription_contract?
      redirect_to subscriptions_path, alert: 'Not a valid subscription.'
    end
  end
end
