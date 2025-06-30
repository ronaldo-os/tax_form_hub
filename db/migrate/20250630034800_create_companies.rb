class CreateCompanies < ActiveRecord::Migration[7.2]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :address_line1
      t.string :address_line2
      t.string :address_line3
      t.string :zip_city
      t.string :country
      t.string :company_number
      t.string :tax_number

      t.timestamps
    end
  end
end
