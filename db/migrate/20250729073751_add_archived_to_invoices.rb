class AddArchivedToInvoices < ActiveRecord::Migration[7.0]
  def change
    add_column :invoices, :archived, :boolean, default: false
  end
end
