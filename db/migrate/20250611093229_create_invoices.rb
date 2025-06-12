class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      t.string :invoice_number
      t.date :issue_date
      t.string :currency
      t.date :payment_due_date
      t.integer :item_id
      t.text :description
      t.integer :quantity
      t.string :unit
      t.decimal :price_per_unit
      t.decimal :tax
      t.decimal :total
      t.text :recipient_note
      t.string :header_type
      t.text :header_description
      t.integer :header_qty
      t.string :header_unit
      t.decimal :header_tax
      t.decimal :header_total
      t.decimal :pricing_discount
      t.string :bank_name
      t.string :bank_sort_code
      t.string :bank_account_number
      t.string :bank_account_holder
      t.string :bank_street_name
      t.string :bank_builder_number
      t.string :bank_city
      t.string :bank_zip_code
      t.string :bank_region
      t.string :bank_address_line
      t.string :bank_country
      t.text :bank_payment_note
      t.string :attachment

      t.timestamps
    end
  end
end
