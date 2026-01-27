class CreateTaxRates < ActiveRecord::Migration[7.2]
  def change
    create_table :tax_rates do |t|
      t.string :name
      t.decimal :rate
      t.references :company, null: true, foreign_key: true
      t.boolean :custom

      t.timestamps
    end
  end
end
