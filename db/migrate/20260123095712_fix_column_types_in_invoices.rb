class FixColumnTypesInInvoices < ActiveRecord::Migration[7.2]
  def up
    # Change recipient_company_id from string to bigint
    # Using 'USING recipient_company_id::bigint' for PostgreSQL
    change_column :invoices, :recipient_company_id, 'bigint USING recipient_company_id::bigint'
    
    # Change sale_from_id from integer to bigint
    change_column :invoices, :sale_from_id, :bigint
    
    # Change recurring_origin_invoice_id from integer to bigint
    change_column :invoices, :recurring_origin_invoice_id, :bigint
  end

  def down
    change_column :invoices, :recipient_company_id, :string
    change_column :invoices, :sale_from_id, :integer
    change_column :invoices, :recurring_origin_invoice_id, :integer
  end
end
