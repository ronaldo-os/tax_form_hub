class AddInvoiceTypeToInvoices < ActiveRecord::Migration[7.0]
  def change
    add_column :invoices, :invoice_type, :string
  end
end
