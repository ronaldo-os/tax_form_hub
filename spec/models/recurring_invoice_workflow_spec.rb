require 'rails_helper'

RSpec.describe 'Recurring Invoice Workflow', type: :model do
  let(:user) { create(:user) }
  let(:company) { create(:company, user: user) }
  let(:subscription) { create(:subscription, user: user, recipient_company: company) }

  describe 'Invoice Numbering' do
    context 'parent invoice generation' do
      it 'generates parent invoice with format YYYY-00001-XXX' do
        invoice_number = Invoice.next_invoice_number_for_user(user, 'sale', 'standard')
        expect(invoice_number).to match(/\d{4}-\d{5}-\d{3}/)
      end

      it 'creates parent invoice without recurring_parent_invoice_id' do
        invoice = subscription.generate_next_invoice
        expect(invoice.recurring_parent_invoice_id).to be_nil
        expect(invoice.recurring_parent_invoice?).to be true
      end

      it 'stores invoice as parent with subscription_id' do
        invoice = subscription.generate_next_invoice
        expect(invoice.subscription_id).to eq(subscription.id)
        expect(invoice.recurring_parent_invoice_id).to be_nil
      end
    end

    context 'sub-invoice generation' do
      let(:parent_invoice) { subscription.generate_next_invoice }

      it 'generates sub-invoice with parent-number-NN format' do
        parent_number = parent_invoice.invoice_number
        sub_invoice_number = Invoice.next_recurring_sub_invoice_number(parent_invoice)
        expect(sub_invoice_number).to eq("#{parent_number}-01")
      end

      it 'creates sub-invoice linked to parent' do
        subscription.generate_next_invoice  # Create parent
        sub_invoice = subscription.generate_next_invoice  # Create sub-invoice

        expect(sub_invoice.recurring_parent_invoice_id).to eq(parent_invoice.id)
        expect(sub_invoice.recurring_sub_invoice?).to be true
        expect(sub_invoice.recurring_sequence_number).to eq(1)
      end

      it 'increments sequence number for each sub-invoice' do
        subscription.generate_next_invoice  # 1. Parent

        sub1 = subscription.generate_next_invoice  # 2. Sub-01
        expect(sub1.invoice_number).to end_with('-01')
        expect(sub1.recurring_sequence_number).to eq(1)

        sub2 = subscription.generate_next_invoice  # 3. Sub-02
        expect(sub2.invoice_number).to end_with('-02')
        expect(sub2.recurring_sequence_number).to eq(2)

        sub3 = subscription.generate_next_invoice  # 4. Sub-03
        expect(sub3.invoice_number).to end_with('-03')
        expect(sub3.recurring_sequence_number).to eq(3)
      end
    end
  end

  describe 'Invoice Relationships' do
    let(:parent_invoice) { subscription.generate_next_invoice }

    it 'parent invoice tracks sub-invoices' do
      subscription.generate_next_invoice  # Create parent
      sub1 = subscription.generate_next_invoice
      sub2 = subscription.generate_next_invoice

      expect(parent_invoice.recurring_sub_invoices.count).to eq(2)
      expect(parent_invoice.recurring_sub_invoices).to include(sub1, sub2)
    end

    it 'sub-invoice references parent invoice' do
      subscription.generate_next_invoice  # Create parent
      sub_invoice = subscription.generate_next_invoice

      expect(sub_invoice.recurring_parent_invoice).to eq(parent_invoice)
    end
  end

  describe 'Validations' do
    context 'invoice_number_unique_per_user' do
      it 'prevents duplicate invoice numbers for same user' do
        invoice1 = create(:invoice, user: user, invoice_number: '2026-00001-001')
        invoice2 = build(:invoice, user: user, invoice_number: '2026-00001-001')

        expect(invoice2).not_to be_valid
        expect(invoice2.errors[:invoice_number]).to include("has already been used for this user")
      end

      it 'allows same invoice number for different users' do
        user2 = create(:user)
        invoice1 = create(:invoice, user: user, invoice_number: '2026-00001-001')
        invoice2 = create(:invoice, user: user2, invoice_number: '2026-00001-001')

        expect(invoice2).to be_valid
      end
    end

    context 'invoice_numbering_structure_valid' do
      it 'validates sub-invoice follows parent format' do
        parent = subscription.generate_next_invoice
        sub_invoice = build(:invoice, 
                             user: user,
                             invoice_number: '2026-00001-001-01',
                             recurring_parent_invoice: parent)

        expect(sub_invoice).to be_valid
      end

      it 'rejects sub-invoice with wrong parent format' do
        parent = subscription.generate_next_invoice
        sub_invoice = build(:invoice,
                             user: user,
                             invoice_number: 'WRONG-NUMBER',
                             recurring_parent_invoice: parent)

        expect(sub_invoice).not_to be_valid
        expect(sub_invoice.errors[:invoice_number]).to include(/must follow parent number format/)
      end

      it 'rejects sub-invoice with non-2-digit sequence' do
        parent = subscription.generate_next_invoice
        parent_num = parent.invoice_number
        
        sub_invoice = build(:invoice,
                             user: user,
                             invoice_number: "#{parent_num}-1",  # Only 1 digit
                             recurring_parent_invoice: parent)

        expect(sub_invoice).not_to be_valid
        expect(sub_invoice.errors[:invoice_number]).to include(/sequence must be two digits/)
      end
    end
  end

  describe 'Invoice Info Storage' do
    let(:parent_invoice) { subscription.generate_next_invoice }

    it 'stores parent invoice reference in parent invoice_info' do
      expect(parent_invoice.invoice_info[:parent_invoice_id]).to be_nil
    end

    it 'stores parent invoice reference in sub-invoice invoice_info' do
      subscription.generate_next_invoice  # Create parent
      sub_invoice = subscription.generate_next_invoice

      expect(sub_invoice.invoice_info[:parent_invoice_id]).to eq(parent_invoice.id)
    end

    it 'includes billing period in invoice_info' do
      invoice = subscription.generate_next_invoice
      
      expect(invoice.invoice_info[:billing_period_start]).to be_present
      expect(invoice.invoice_info[:billing_period_end]).to be_present
    end
  end

  describe 'Subscription Updates' do
    it 'updates subscription period after invoice generation' do
      original_period_end = subscription.current_period_end
      
      invoice = subscription.generate_next_invoice
      subscription.reload

      expect(subscription.current_period_start).to eq(original_period_end)
      expect(subscription.current_period_end).to be > original_period_end
      expect(subscription.next_invoice_date).to be > original_period_end
    end
  end

  describe 'Database Constraints' do
    it 'creates unique index on [user_id, invoice_number]' do
      # This tests that the migration created the unique index
      # Verify through database schema
      indexes = Invoice.connection.indexes(:invoices)
      index = indexes.find { |i| i.columns == ['user_id', 'invoice_number'] }
      
      expect(index).to be_present
      expect(index.unique).to be true
    end
  end

  describe 'Queries for Recurring Invoices' do
    before do
      @parent = subscription.generate_next_invoice
      @sub1 = subscription.generate_next_invoice
      @sub2 = subscription.generate_next_invoice
    end

    it 'finds parent invoice for subscription' do
      parent = user.invoices.where(subscription_id: subscription.id, recurring_parent_invoice_id: nil).first
      expect(parent).to eq(@parent)
    end

    it 'finds all sub-invoices for parent' do
      sub_invoices = @parent.recurring_sub_invoices.order(:recurring_sequence_number)
      expect(sub_invoices.count).to eq(2)
      expect(sub_invoices).to eq([@sub1, @sub2])
    end

    it 'lists all invoices for billing setup' do
      all_invoices = @parent.recurring_sub_invoices.to_a + [@parent]
      expect(all_invoices.count).to eq(3)
      expect(all_invoices).to include(@parent, @sub1, @sub2)
    end
  end
end

RSpec.describe GenerateRecurringInvoicesJob, type: :job do
  let(:user) { create(:user) }
  let(:company) { create(:company, user: user) }
  let(:subscription) { create(:subscription, 
                               user: user, 
                               recipient_company: company,
                               next_invoice_date: Date.current - 1.day) }

  it 'generates parent invoice for new subscription' do
    job = GenerateRecurringInvoicesJob.new
    results = job.perform(on_date: Date.current)

    expect(results[:successful]).to eq(1)
    expect(results[:failed]).to eq(0)

    invoice = user.invoices.last
    expect(invoice.recurring_parent_invoice?).to be true
  end

  it 'generates sub-invoice for existing subscription' do
    # Create parent invoice
    subscription.generate_next_invoice
    subscription.update(next_invoice_date: Date.current - 1.day)

    # Run job
    job = GenerateRecurringInvoicesJob.new
    results = job.perform(on_date: Date.current)

    expect(results[:successful]).to eq(1)
    
    sub_invoice = user.invoices.last
    expect(sub_invoice.recurring_sub_invoice?).to be true
  end

  it 'logs parent invoice generation' do
    allow(Rails.logger).to receive(:info)
    
    job = GenerateRecurringInvoicesJob.new
    job.perform(on_date: Date.current)

    expect(Rails.logger).to have_received(:info).with(/parent invoice/)
  end

  it 'logs sub-invoice generation' do
    subscription.generate_next_invoice
    subscription.update(next_invoice_date: Date.current - 1.day)
    
    allow(Rails.logger).to receive(:info)

    job = GenerateRecurringInvoicesJob.new
    job.perform(on_date: Date.current)

    expect(Rails.logger).to have_received(:info).with(/sub-invoice/)
  end
end
