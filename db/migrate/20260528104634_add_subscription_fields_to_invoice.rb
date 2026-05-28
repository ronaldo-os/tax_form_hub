class AddSubscriptionFieldsToInvoice < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :is_subscription, :boolean, default: false, null: false
    add_column :invoices, :subscription_start_date, :date
    add_column :invoices, :next_billing_date, :date
    add_column :invoices, :billing_cycle, :string
    
    # Add index for finding subscription invoices due for billing
    add_index :invoices, [:is_subscription, :next_billing_date], name: "index_invoices_on_subscription_billing"
  end
end
