class SplitZipCityIntoZipCodeAndCity < ActiveRecord::Migration[7.0]
  def change
    add_column :companies, :zip_code, :string
    add_column :companies, :city, :string
    remove_column :companies, :zip_city, :string
  end
end
