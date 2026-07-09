class PriceAdjustmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_price_adjustment, only: [:show]

  def show
    @invoices = @price_adjustment.recurring_sub_invoices.order(issue_date: :desc).limit(10)
    
    @adj = @price_adjustment.recurring_price_adjustments.first || {}
    @cycle = case @adj['frequency']
             when 'annually', 'yearly' then 'annual'
             else 'monthly'
             end
             
    start_date = @adj['charge_start_date']
    if start_date.present? && @price_adjustment.subscription_active?
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
    unless @price_adjustment.has_recurring_price_adjustments? && !@price_adjustment.has_subscription_line_items?
      redirect_to subscriptions_path, alert: 'Not a valid price adjustment.'
    end
  end
end
