class AddCompanyNameToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :tax_submissions, :company_name, :string
  end
end
