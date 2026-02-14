class AddInvoiceCategoryToInvoices < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:invoices, :invoice_category)
      add_column :invoices, :invoice_category, :string, default: 'standard'
    end
  end
end
