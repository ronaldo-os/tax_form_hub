# frozen_string_literal: true

# Example controller for managing subscriptions
# Add this to your app/controllers/subscriptions_controller.rb

class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_subscription, only: [:show, :edit, :update, :pause, :resume, :cancel, :extend]

  # GET /subscriptions
  # List all subscriptions for the current user
  def index
    @subscriptions = current_user.subscriptions.includes(:recipient_company)
      .order(created_at: :desc)
      .page(params[:page])

    @active_subscriptions = @subscriptions.where(status: 'active')
    @paused_subscriptions = @subscriptions.where(status: 'paused')
    @cancelled_subscriptions = @subscriptions.where(status: 'cancelled')
  end

  # GET /subscriptions/:id
  # Show subscription details
  def show
    @invoices = @subscription.invoices.order(issue_date: :desc).limit(10)
    @upcoming_invoice_date = @subscription.next_invoice_date
    @annual_value = @subscription.annual_value
  end

  # GET /subscriptions/new
  # Form for creating a new subscription
  def new
    @subscription = Subscription.new
    @companies = current_user.companies
    @recipient_companies = Company.all  # Or scope to related companies
  end

  # POST /subscriptions
  # Create a new subscription
  def create
    begin
      @subscription = SubscriptionService.create_subscription(
        user: current_user,
        recipient_company: Company.find(subscription_params[:recipient_company_id]),
        sale_from_company: Company.find(subscription_params[:sale_from_company_id]) if subscription_params[:sale_from_company_id].present?,
        start_date: subscription_params[:start_date].to_date,
        billing_cycle: subscription_params[:billing_cycle],
        quantity: subscription_params[:quantity],
        unit_price: subscription_params[:unit_price],
        currency: subscription_params[:currency],
        description: subscription_params[:description],
        end_date: subscription_params[:end_date].to_date if subscription_params[:end_date].present?
      )

      redirect_to @subscription, notice: 'Subscription created successfully.'
    rescue StandardError => e
      redirect_to new_subscription_path, alert: "Failed to create subscription: #{e.message}"
    end
  end

  # GET /subscriptions/:id/edit
  # Form for editing subscription pricing
  def edit
    @companies = current_user.companies
  end

  # PATCH/PUT /subscriptions/:id
  # Update subscription (applies to next billing period)
  def update
    begin
      @subscription.assign_attributes(subscription_params)

      if subscription_params[:unit_price].present?
        SubscriptionService.update_subscription_price(
          @subscription,
          subscription_params[:unit_price]
        )
      end

      if subscription_params[:quantity].present?
        SubscriptionService.update_subscription_quantity(
          @subscription,
          subscription_params[:quantity]
        )
      end

      redirect_to @subscription, notice: 'Subscription updated successfully.'
    rescue StandardError => e
      redirect_to edit_subscription_path(@subscription), alert: "Update failed: #{e.message}"
    end
  end

  # POST /subscriptions/:id/pause
  # Pause a subscription temporarily
  def pause
    begin
      SubscriptionService.pause_subscription(@subscription)
      redirect_to @subscription, notice: 'Subscription paused.'
    rescue StandardError => e
      redirect_to @subscription, alert: "Failed to pause: #{e.message}"
    end
  end

  # POST /subscriptions/:id/resume
  # Resume a paused subscription
  def resume
    begin
      SubscriptionService.resume_subscription(@subscription)
      redirect_to @subscription, notice: 'Subscription resumed.'
    rescue StandardError => e
      redirect_to @subscription, alert: "Failed to resume: #{e.message}"
    end
  end

  # POST /subscriptions/:id/cancel
  # Cancel a subscription
  def cancel
    begin
      SubscriptionService.cancel_subscription(@subscription)
      redirect_to subscriptions_path, notice: 'Subscription cancelled.'
    rescue StandardError => e
      redirect_to @subscription, alert: "Failed to cancel: #{e.message}"
    end
  end

  # POST /subscriptions/:id/extend
  # Extend subscription end date
  def extend
    begin
      new_end_date = params[:end_date].to_date
      SubscriptionService.extend_subscription(@subscription, new_end_date)
      redirect_to @subscription, notice: 'Subscription extended.'
    rescue StandardError => e
      redirect_to @subscription, alert: "Failed to extend: #{e.message}"
    end
  end

  # POST /subscriptions/:id/generate_invoice
  # Manually generate an invoice for a subscription
  def generate_invoice
    begin
      if !@subscription.due_for_invoicing?
        raise "Subscription is not due for invoicing yet. Next invoice date: #{@subscription.next_invoice_date}"
      end

      invoice = SubscriptionService.generate_invoice_from_subscription(
        subscription: @subscription,
        invoice_number: params[:invoice_number]
      )

      redirect_to invoice_path(invoice), notice: 'Invoice generated successfully.'
    rescue StandardError => e
      redirect_to @subscription, alert: "Failed to generate invoice: #{e.message}"
    end
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
    authorize_subscription!
  end

  def authorize_subscription!
    redirect_to subscriptions_path, alert: 'Not authorized' unless @subscription.user == current_user
  end

  def subscription_params
    params.require(:subscription).permit(
      :recipient_company_id,
      :sale_from_company_id,
      :billing_cycle,
      :quantity,
      :unit_price,
      :currency,
      :description,
      :start_date,
      :end_date
    )
  end
end
