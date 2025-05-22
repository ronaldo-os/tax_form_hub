class CreateTaxSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :tax_submissions do |t|
      t.string :email
      t.text :details
      t.timestamps
    end
  end
end