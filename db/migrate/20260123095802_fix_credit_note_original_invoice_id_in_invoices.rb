class FixCreditNoteOriginalInvoiceIdInInvoices < ActiveRecord::Migration[7.2]
  def change
    change_column :invoices, :credit_note_original_invoice_id, :bigint
  end
end
