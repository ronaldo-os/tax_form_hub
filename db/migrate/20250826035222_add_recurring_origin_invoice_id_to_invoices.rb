class AddRecurringOriginInvoiceIdToInvoices < ActiveRecord::Migration[7.2]
  def change
    add_column :invoices, :recurring_origin_invoice_id, :integer
  end
end
