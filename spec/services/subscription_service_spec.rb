# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubscriptionService do
  let(:user) { create(:user) }
  let(:customer) { create(:company, user: user) }

  describe '.create_subscription' do
    it 'creates a subscription with proper initial state' do
      subscription = SubscriptionService.create_subscription(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99,
        description: 'Premium Plan'
      )

      expect(subscription).to be_persisted
      expect(subscription.user).to eq(user)
      expect(subscription.recipient_company).to eq(customer)
      expect(subscription.status).to eq('active')
      expect(subscription.current_period_end).to eq(Date.new(2024, 2, 1))
    end
  end

  describe '.add_mid_cycle_adjustment' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 300
      ).tap(&:save!)
    end

    it 'calculates prorated amount for mid-cycle addition' do
      adjustment = SubscriptionService.add_mid_cycle_adjustment(
        subscription: subscription,
        quantity_change: 2,
        effective_date: Date.new(2024, 1, 15)
      )

      # 15 days remaining in January (Jan 15-31)
      # Full price for 2 units: $600
      # Prorated: $600 * (17 / 31) = $329.03
      expect(adjustment[:adjustment_amount]).to be > 0
      expect(adjustment[:adjustment_amount]).to be < 600
      expect(adjustment[:remaining_days]).to eq(17)
      expect(adjustment[:cycle_days]).to eq(31)
    end

    it 'stores adjustments in subscription metadata' do
      SubscriptionService.add_mid_cycle_adjustment(
        subscription: subscription,
        quantity_change: 5,
        effective_date: Date.new(2024, 1, 20)
      )

      subscription.reload
      expect(subscription.metadata['adjustments']).not_to be_empty
      expect(subscription.metadata['adjustments'].first[:type]).to eq('mid_cycle_adjustment')
    end

    it 'raises error if subscription not active' do
      subscription.cancel!
      expect {
        SubscriptionService.add_mid_cycle_adjustment(
          subscription: subscription,
          quantity_change: 1,
          effective_date: Date.new(2024, 1, 15)
        )
      }.to raise_error('Subscription must be active')
    end
  end

  describe '.generate_invoice_from_subscription' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99,
        description: 'Premium Plan'
      ).tap(&:save!)
    end

    it 'generates invoice from subscription' do
      invoice = SubscriptionService.generate_invoice_from_subscription(
        subscription: subscription
      )

      expect(invoice).to be_persisted
      expect(invoice.subscription).to eq(subscription)
      expect(invoice.recipient_company).to eq(customer)
    end

    it 'raises error if subscription not due' do
      subscription.update(next_invoice_date: Date.current + 10.days)
      expect {
        SubscriptionService.generate_invoice_from_subscription(
          subscription: subscription
        )
      }.to raise_error('Subscription must be due for invoicing')
    end
  end

  describe '.pause_subscription' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'pauses the subscription' do
      SubscriptionService.pause_subscription(subscription)
      expect(subscription.reload).to be_paused
    end
  end

  describe '.resume_subscription' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'resumes a paused subscription' do
      subscription.pause!
      SubscriptionService.resume_subscription(subscription)
      expect(subscription.reload).to be_active
    end
  end

  describe '.cancel_subscription' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'cancels the subscription' do
      SubscriptionService.cancel_subscription(subscription)
      expect(subscription.reload).to be_cancelled
    end
  end

  describe '.extend_subscription' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        end_date: 1.year.from_now,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'extends subscription end date' do
      new_end_date = 2.years.from_now.to_date
      SubscriptionService.extend_subscription(subscription, new_end_date)

      expect(subscription.reload.end_date).to eq(new_end_date)
    end

    it 'raises error if new date not after current' do
      expect {
        SubscriptionService.extend_subscription(
          subscription,
          subscription.end_date - 1.day
        )
      }.to raise_error('New end date must be after current end date')
    end
  end

  describe '.update_subscription_quantity' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'updates quantity' do
      SubscriptionService.update_subscription_quantity(subscription, 5)
      expect(subscription.reload.quantity).to eq(5)
    end

    it 'raises error for invalid quantity' do
      expect {
        SubscriptionService.update_subscription_quantity(subscription, 0)
      }.to raise_error('Quantity must be greater than 0')
    end
  end

  describe '.update_subscription_price' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99
      ).tap(&:save!)
    end

    it 'updates unit price' do
      SubscriptionService.update_subscription_price(subscription, 149.99)
      expect(subscription.reload.unit_price).to eq(149.99)
    end

    it 'raises error for invalid price' do
      expect {
        SubscriptionService.update_subscription_price(subscription, -10)
      }.to raise_error('Unit price must be greater than 0')
    end
  end
end
