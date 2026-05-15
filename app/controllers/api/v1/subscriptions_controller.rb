# frozen_string_literal: true

# API controller for subscriptions
# Add this to your app/controllers/api/v1/subscriptions_controller.rb

module Api
  module V1
    class SubscriptionsController < ApiBaseController
      before_action :authenticate_user!
      before_action :set_subscription, only: [:show, :update, :pause, :resume, :cancel, :invoices]

      # GET /api/v1/subscriptions
      # List subscriptions with optional filters
      def index
        subscriptions = current_user.subscriptions.includes(:recipient_company)

        # Filter by status
        subscriptions = subscriptions.where(status: params[:status]) if params[:status].present?

        # Filter by billing cycle
        subscriptions = subscriptions.where(billing_cycle: params[:billing_cycle]) if params[:billing_cycle].present?

        # Filter by company
        subscriptions = subscriptions.where(recipient_company_id: params[:company_id]) if params[:company_id].present?

        render json: subscriptions, each_serializer: SubscriptionSerializer
      end

      # GET /api/v1/subscriptions/:id
      def show
        render json: @subscription, serializer: SubscriptionDetailSerializer
      end

      # POST /api/v1/subscriptions
      def create
        begin
          subscription = SubscriptionService.create_subscription(
            user: current_user,
            recipient_company: Company.find(subscription_params[:recipient_company_id]),
            sale_from_company: subscription_params[:sale_from_company_id].present? ? 
              Company.find(subscription_params[:sale_from_company_id]) : nil,
            start_date: subscription_params[:start_date]&.to_date || Date.current,
            billing_cycle: subscription_params[:billing_cycle],
            quantity: subscription_params[:quantity],
            unit_price: subscription_params[:unit_price],
            currency: subscription_params[:currency] || 'USD',
            description: subscription_params[:description]
          )

          render json: subscription, serializer: SubscriptionDetailSerializer, status: :created
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/subscriptions/:id
      def update
        begin
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

          @subscription.update!(subscription_params.slice(:description))

          render json: @subscription, serializer: SubscriptionDetailSerializer
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/subscriptions/:id/pause
      def pause
        begin
          SubscriptionService.pause_subscription(@subscription)
          render json: @subscription, serializer: SubscriptionDetailSerializer
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/subscriptions/:id/resume
      def resume
        begin
          SubscriptionService.resume_subscription(@subscription)
          render json: @subscription, serializer: SubscriptionDetailSerializer
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/subscriptions/:id/cancel
      def cancel
        begin
          SubscriptionService.cancel_subscription(@subscription)
          render json: { message: 'Subscription cancelled' }, status: :ok
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/subscriptions/:id/invoices
      def invoices
        invoices = @subscription.invoices
          .order(issue_date: :desc)
          .limit(params[:limit] || 20)

        render json: invoices, each_serializer: InvoiceSerializer
      end

      # POST /api/v1/subscriptions/:id/mid-cycle-adjustment
      def add_adjustment
        begin
          adjustment = SubscriptionService.add_mid_cycle_adjustment(
            subscription: @subscription,
            quantity_change: adjustment_params[:quantity_change],
            effective_date: adjustment_params[:effective_date]&.to_date || Date.current
          )

          render json: adjustment, status: :created
        rescue StandardError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/subscriptions/due-for-invoicing
      def due_for_invoicing
        subscriptions = Subscription.due_for_invoicing(Date.current)
          .where(user_id: current_user.id)

        render json: subscriptions, each_serializer: SubscriptionSerializer
      end

      private

      def set_subscription
        @subscription = Subscription.find(params[:id])
        authorize_subscription!
      end

      def authorize_subscription!
        render json: { error: 'Not authorized' }, status: :forbidden unless @subscription.user == current_user
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

      def adjustment_params
        params.require(:adjustment).permit(:quantity_change, :effective_date)
      end
    end
  end
end
