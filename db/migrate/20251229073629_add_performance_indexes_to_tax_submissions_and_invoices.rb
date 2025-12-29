class AddPerformanceIndexesToTaxSubmissionsAndInvoices < ActiveRecord::Migration[7.2]
  def change
    # Optimize admin dashboard filtering and sorting
    add_index :tax_submissions, [:company_id, :archived, :created_at], name: 'index_tax_submissions_on_company_archived_created'
    
    # Optimize user home dashboard filtering and sorting
    add_index :tax_submissions, [:email, :archived, :created_at], name: 'index_tax_submissions_on_email_archived_created'
    
    # Optimize invoice lookup in fetch_invoices
    add_index :invoices, [:recipient_company_id, :status], name: 'index_invoices_on_recipient_and_status'
  end
end
