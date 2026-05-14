# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GenerateRecurringInvoicesJob, type: :job do
  let(:user) { create(:user) }
  let(:customer) { create(:company, user: user) }

  describe '#perform' do
    it 'generates invoices for all due subscriptions' do
      # Create subscription due today
      sub1 = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      sub1.save!

      # Create subscription due in future
      sub2 = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current + 10.days,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      sub2.update_column(:next_invoice_date, Date.current + 10.days)

      expect {
        GenerateRecurringInvoicesJob.perform_now
      }.to change { Invoice.count }.by(1)
    end

    it 'updates subscription state after invoice generation' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!

      GenerateRecurringInvoicesJob.perform_now

      subscription.reload
      expect(subscription.renewal_count).to eq(1)
      expect(subscription.last_invoice_generated_at).not_to be_nil
    end

    it 'returns job result statistics' do
      # Create one due subscription
      Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      ).save!

      result = GenerateRecurringInvoicesJob.perform_now

      expect(result[:total]).to eq(1)
      expect(result[:successful]).to eq(1)
      expect(result[:failed]).to eq(0)
    end

    it 'handles errors gracefully' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!

      # Mock invoice save to fail
      allow_any_instance_of(Invoice).to receive(:save).and_return(false)
      allow_any_instance_of(Invoice).to receive(:errors)
        .and_return(double(full_messages: ['Invoice error']))

      result = GenerateRecurringInvoicesJob.perform_now

      expect(result[:failed]).to eq(1)
      expect(result[:errors]).not_to be_empty
    end

    it 'skips paused subscriptions' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!
      subscription.pause!

      expect {
        GenerateRecurringInvoicesJob.perform_now
      }.not_to change { Invoice.count }
    end

    it 'skips cancelled subscriptions' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.current,
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!
      subscription.cancel!

      expect {
        GenerateRecurringInvoicesJob.perform_now
      }.not_to change { Invoice.count }
    end

    it 'allows specifying a custom date' do
      subscription = Subscription.create_with_periods(
        user: user,
        recipient_company: customer,
        start_date: Date.new(2024, 1, 1),
        billing_cycle: 'monthly',
        quantity: 1,
        unit_price: 100
      )
      subscription.save!

      expect {
        GenerateRecurringInvoicesJob.perform_now(on_date: Date.new(2024, 1, 1))
      }.to change { Invoice.count }.by(1)
    end
  end
end
