# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Subscription, type: :model do
  let(:user) { create(:user) }
  let(:customer) { create(:company, user: user) }

  describe 'validations' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:billing_cycle) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_presence_of(:unit_price) }

    it 'validates quantity is greater than 0' do
      subscription.quantity = 0
      expect(subscription).not_to be_valid
    end

    it 'validates unit_price is greater than 0' do
      subscription.unit_price = -10
      expect(subscription).not_to be_valid
    end

    it 'validates end_date is after start_date' do
      subscription.end_date = subscription.start_date - 1.day
      expect(subscription).not_to be_valid
    end
  end

  describe '.create_with_periods' do
    it 'creates subscription with calculated period dates' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 15),
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!

      expect(subscription.current_period_start).to eq(Date.new(2024, 1, 15))
      expect(subscription.current_period_end).to eq(Date.new(2024, 2, 15))
      expect(subscription.next_invoice_date).to eq(Date.new(2024, 1, 15))
    end

    it 'calculates quarterly periods' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        billing_cycle: 'quarterly',
        quantity: 1,
        unit_price: 300
      )
      subscription.save!

      expect(subscription.current_period_end).to eq(Date.new(2024, 4, 1))
    end

    it 'calculates annual periods' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 3, 1),
        billing_cycle: 'annual',
        quantity: 1,
        unit_price: 1200
      )
      subscription.save!

      expect(subscription.current_period_end).to eq(Date.new(2025, 3, 1))
    end
  end

  describe '#active_on?' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        end_date: Date.new(2024, 12, 31),
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    before { subscription.save! }

    it 'returns true for dates within the subscription period' do
      expect(subscription.active_on?(Date.new(2024, 6, 15))).to be true
    end

    it 'returns false for dates before start' do
      expect(subscription.active_on?(Date.new(2023, 12, 31))).to be false
    end

    it 'returns false for dates on or after end_date' do
      expect(subscription.active_on?(Date.new(2024, 12, 31))).to be false
    end

    it 'returns false if not active' do
      subscription.cancel!
      expect(subscription.active_on?(Date.new(2024, 6, 15))).to be false
    end
  end

  describe '#due_for_invoicing?' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    before { subscription.save! }

    it 'returns true when next_invoice_date is today or earlier' do
      expect(subscription.due_for_invoicing?).to be true
    end

    it 'returns false when next_invoice_date is in the future' do
      subscription.update(next_invoice_date: Date.current + 10.days)
      expect(subscription.due_for_invoicing?).to be false
    end
  end

  describe '#generate_next_invoice' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 99.99,
        description: 'Premium Support'
      )
    end

    before { subscription.save! }

    it 'creates an invoice with proper details' do
      invoice = subscription.generate_next_invoice

      expect(invoice).to be_persisted
      expect(invoice.subscription).to eq(subscription)
      expect(invoice.user).to eq(user)
      expect(invoice.recipient_company).to eq(customer)
      expect(invoice.invoice_type).to eq('sale')
      expect(invoice.invoice_category).to eq('standard')
    end

    it 'updates subscription for next renewal' do
      old_next_date = subscription.next_invoice_date
      old_period_start = subscription.current_period_start
      old_period_end = subscription.current_period_end

      subscription.generate_next_invoice

      subscription.reload
      expect(subscription.renewal_count).to eq(1)
      expect(subscription.current_period_start).to eq(old_period_end)
      expect(subscription.next_invoice_date).to eq(old_period_end)
      expect(subscription.renewal_count).to be > 0
    end

    it 'raises error if not due for invoicing' do
      subscription.update(next_invoice_date: Date.current + 10.days)
      expect { subscription.generate_next_invoice }.to raise_error('Cannot generate invoice')
    end

    it 'raises error if not active' do
      subscription.cancel!
      expect { subscription.generate_next_invoice }.to raise_error('Cannot generate invoice')
    end
  end

  describe '#pause! and #resume!' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    before { subscription.save! }

    it 'pauses the subscription' do
      subscription.pause!
      expect(subscription.reload).to be_paused
    end

    it 'resumes a paused subscription' do
      subscription.pause!
      subscription.resume!
      expect(subscription.reload).to be_active
    end

    it 'sets next_invoice_date to today on resume' do
      subscription.pause!
      subscription.update(next_invoice_date: Date.current + 20.days)
      subscription.resume!
      expect(subscription.reload.next_invoice_date).to eq(Date.current)
    end
  end

  describe '#cancel!' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    before { subscription.save! }

    it 'cancels the subscription' do
      subscription.cancel!
      expect(subscription.reload).to be_cancelled
    end

    it 'sets end_date to today' do
      subscription.cancel!
      expect(subscription.reload.end_date).to eq(Date.current)
    end
  end

  describe '#build_line_items_for_invoice' do
    let(:subscription) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        billing_cycle: 'monthly',
        quantity: 5,
        unit_price: 50.00,
        description: 'SaaS Service',
        currency: 'EUR'
      )
    end

    before { subscription.save! }

    it 'builds proper line items with subscription data' do
      line_items = subscription.build_line_items_for_invoice
      item = line_items.first

      expect(item['description']).to eq('SaaS Service')
      expect(item['quantity']).to eq('5')
      expect(item['price']).to eq('50.0')
      expect(item['optional_fields']['subscription']['start_date']).to eq('2024-01-01')
      expect(item['optional_fields']['subscription']['billing_cycle']).to eq('monthly')
    end
  end

  describe '.due_for_invoicing scope' do
    before do
      # Create subscription due today
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      ).save!

      # Create subscription due in future
      future_sub = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current + 10.days,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      future_sub.update_column(:next_invoice_date, Date.current + 10.days)
      future_sub.save!

      # Create inactive subscription
      inactive = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      inactive.cancel!
    end

    it 'returns only subscriptions due today or earlier' do
      due = Subscription.due_for_invoicing(Date.current)
      expect(due.count).to eq(1)
    end
  end

  describe '#annual_value' do
    let(:monthly_sub) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
    end

    let(:quarterly_sub) do
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'quarterly',
        quantity: 1,
        unit_price: 300
      )
    end

    it 'calculates annual value for monthly billing' do
      monthly_sub.save!
      expect(monthly_sub.annual_value).to eq(1200)
    end

    it 'calculates annual value for quarterly billing' do
      quarterly_sub.save!
      expect(quarterly_sub.annual_value).to eq(1200)
    end
  end
end
