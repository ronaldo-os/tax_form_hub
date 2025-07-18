class RecreateInvoicesTable < ActiveRecord::Migration[7.2]
  def change
    drop_table :invoices, if_exists: true

    create_table :invoices do |t|
      t.references :user, foreign_key: true
      t.string  :recipient_company_id
      t.string  :invoice_number
      t.date    :issue_date
      t.string  :currency

      t.jsonb   :line_items_data, default: []
      t.jsonb   :payment_terms, default: []
      t.jsonb   :header_charge_discount_tax, default: []
      t.jsonb   :price_adjustments , default: []

      t.text    :recipient_note

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

      # Location references
      t.references :ship_from_location, foreign_key: { to_table: :locations }
      t.references :remit_to_location, foreign_key: { to_table: :locations }
      t.references :tax_representative_location, foreign_key: { to_table: :locations }

      # Other meta
      t.text    :message
      t.text    :footer_notes
      t.boolean :save_notes_for_future, default: false
      t.boolean :save_footer_notes_for_future, default: false
      t.boolean :save_payment_terms_for_future, default: false

      t.timestamps
    end
  end
end
