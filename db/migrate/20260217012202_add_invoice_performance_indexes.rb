class AddInvoicePerformanceIndexes < ActiveRecord::Migration[7.2]
  def change
    # Composite index for invoice index page queries (filtering by user, type, category, archived, sorting by date)
    add_index :invoices, [:user_id, :invoice_type, :invoice_category, :archived, :issue_date],
      name: 'index_invoices_on_user_type_category_archived_date'
    
    # Index for credit note lookups (finding eligible invoices for credit notes)
    add_index :invoices, [:user_id, :invoice_category, :invoice_type, :status],
      name: 'index_invoices_on_user_category_type_status'
    
    # Index for location queries by user and type (used in form selectors)
    add_index :locations, [:user_id, :location_type],
      name: 'index_locations_on_user_and_type'
  end
end
