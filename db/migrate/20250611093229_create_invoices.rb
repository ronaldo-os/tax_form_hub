class CreateInvoices < ActiveRecord::Migration[7.2]
  def change
    create_table :invoices do |t|
      t.references :user, foreign_key: true
      t.string  :invoice_number
      t.date    :issue_date
      t.string  :currency
      t.date    :payment_due_date
      t.date    :delivery_date
      t.string  :recipient_company_id

      # Store all line items as JSON array of hashes
      t.jsonb   :line_items_data, default: []

      t.text    :recipient_note
      t.string  :header_type
      t.text    :header_description
      t.integer :header_qty
      t.string  :header_unit
      t.decimal :header_tax
      t.decimal :header_total
      t.decimal :pricing_discount

      # Bank details
      t.string  :bank_name
      t.string  :bank_sort_code
      t.string  :bank_account_number
      t.string  :bank_account_holder
      t.string  :bank_street_name
      t.string  :bank_builder_number
      t.string  :bank_city
      t.string  :bank_zip_code
      t.string  :bank_region
      t.string  :bank_address_line
      t.string  :bank_country
      t.text    :bank_payment_note

      # Delivery details
      t.string  :delivery_details_country
      t.string  :delivery_details_postbox
      t.string  :delivery_details_street
      t.string  :delivery_details_number
      t.string  :delivery_details_locality_name
      t.string  :delivery_details_zip_code
      t.string  :delivery_details_city
      t.string  :delivery_details_gln
      t.string  :delivery_details_company_name
      t.string  :delivery_details_tax_id
      t.string  :delivery_details_tax_number

      # Other meta
      t.text    :message
      t.text    :footer_notes
      t.boolean :save_notes_for_future, default: false
      t.boolean :save_footer_notes_for_future, default: false
      t.boolean :save_payment_terms_for_future, default: false

      t.string  :attachment

      t.timestamps
    end
  end
end
