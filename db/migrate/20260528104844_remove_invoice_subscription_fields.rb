class RemoveInvoiceSubscriptionFields < ActiveRecord::Migration[7.2]
  def change
    remove_index :invoices, name: "index_invoices_on_subscription_billing"
    remove_column :invoices, :is_subscription
    remove_column :invoices, :subscription_start_date
    remove_column :invoices, :next_billing_date
    remove_column :invoices, :billing_cycle
  end
end
