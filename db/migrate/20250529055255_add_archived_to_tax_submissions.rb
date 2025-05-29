class AddArchivedToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :tax_submissions, :archived, :boolean
  end
end
