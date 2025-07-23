class AddTotalToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :total, :jsonb, default: {}, null: false
  end
end
