# frozen_string_literal: true

# Example controller for managing subscriptions
# Add this to your app/controllers/subscriptions_controller.rb

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription_invoice, only: [:show, :cancel]

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

  private

  def set_subscription_invoice
    @subscription = current_user.invoices.find(params[:id])
    unless @subscription.subscription_contract?
      redirect_to subscriptions_path, alert: 'Not a valid subscription.'
    end
  end
end
