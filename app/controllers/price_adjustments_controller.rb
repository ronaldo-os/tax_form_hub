class PriceAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_price_adjustment, only: [:show]
  before_action -> { store_back_url(:price_adjustment_back_url) }, only: [:show]

  def show
    @invoices = @price_adjustment.recurring_sub_invoices.order(issue_date: :desc).limit(10)
    
    first_recurring_idx = (@price_adjustment.price_adjustments || []).index do |adj|
      next false unless adj.is_a?(Hash)
      freq = adj['frequency'] || adj[:frequency] || (adj['unit'] == 'monthly_charge' || adj[:unit] == 'monthly_charge' ? 'monthly' : nil)
      %w[monthly annually yearly].include?(freq.to_s)
    end

    @item_index = if params[:item_index].present?
                    params[:item_index].to_i
                  elsif params[:adjustment_index].present?
                    params[:adjustment_index].to_i
                  else
                    first_recurring_idx || 0
                  end

    @adj = if @item_index && @price_adjustment.price_adjustments.is_a?(Array)
             @price_adjustment.price_adjustments[@item_index] || @price_adjustment.recurring_price_adjustments.first || {}
           else
             @price_adjustment.recurring_price_adjustments.first || {}
           end

    @cycle = case @adj['frequency']
             when 'annually', 'yearly' then 'annual'
             else 'monthly'
             end

    @wrapper = PriceAdjustmentItemWrapper.new(@price_adjustment, @adj, @item_index)

    start_date = @adj['charge_start_date']
    if start_date.present? && @wrapper.subscription_active?
      start_d = Date.parse(start_date) rescue nil
      if start_d
        current_sequence = @price_adjustment.recurring_sub_invoices.count + 1
        next_date = start_d
        current_sequence.times do
          next_date = @price_adjustment.calculate_next_period_date(next_date, @cycle)
        end
        @upcoming_invoice_date = next_date
      end
    end
  end

  private

  def set_price_adjustment
    @price_adjustment = current_user.invoices.find(params[:id])
    unless @price_adjustment.has_recurring_price_adjustments?
      redirect_to subscriptions_path, alert: 'Not a valid price adjustment.'
    end
  end
end
