class AddInvoiceInfoToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :invoice_info, :jsonb, default: {}, null: false
  end
end
