class AddSubscriptionReferenceToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_reference :invoices, :subscription, foreign_key: true, null: true
    add_index :invoices, [:subscription_id, :issue_date]
  end
end
