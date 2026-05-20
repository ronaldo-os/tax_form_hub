class AddRecurringParentInvoiceToInvoices < ActiveRecord::Migration[7.2]
  def change
    # Add field to link sub-invoices to their parent recurring invoice
    add_column :invoices, :recurring_parent_invoice_id, :bigint, null: true
    add_index :invoices, :recurring_parent_invoice_id, name: "index_invoices_on_recurring_parent_id"
    
    # Add field to track sequence number for sub-invoices (01, 02, 03, etc.)
    add_column :invoices, :recurring_sequence_number, :integer, null: true
    
    # Add constraint to ensure invoice numbers are unique per user
    add_index :invoices, [:user_id, :invoice_number], unique: true, name: "index_invoices_on_user_and_number_unique"
  end
end
