class AddCountryToCompanies < ActiveRecord::Migration[7.2]
  def change
    add_column :companies, :country, :string
  end
end
