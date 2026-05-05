class RemoveRecurringOriginInvoiceIdFromInvoices < ActiveRecord::Migration[7.2]
  def change
    remove_column :invoices, :recurring_origin_invoice_id, :bigint
  end
end
