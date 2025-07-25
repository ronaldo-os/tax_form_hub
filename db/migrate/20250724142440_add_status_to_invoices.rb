class AddStatusToInvoices < ActiveRecord::Migration[6.1]
  def change
    add_column :invoices, :status, :string, default: "draft"
  end
end