class AddSaleFromIdToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :sale_from_id, :integer
  end
end
