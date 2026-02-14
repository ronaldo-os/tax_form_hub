class FixCreditNoteOriginalInvoiceIdInInvoices < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:invoices, :credit_note_original_invoice_id)
      add_reference :invoices, :credit_note_original_invoice, foreign_key: { to_table: :invoices }, index: false
    end
  end

  def down
    if column_exists?(:invoices, :credit_note_original_invoice_id)
      remove_reference :invoices, :credit_note_original_invoice, foreign_key: { to_table: :invoices }
    end
  end
end
