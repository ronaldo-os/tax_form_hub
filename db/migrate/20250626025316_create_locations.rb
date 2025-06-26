class CreateLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :locations do |t|
      t.string :location_type
      t.string :location_name
      t.string :country
      t.string :company_name
      t.string :tax_number
      t.string :post_box
      t.string :street
      t.string :building
      t.string :additional_street
      t.string :zip_code
      t.string :city

      t.timestamps
    end
  end
end
