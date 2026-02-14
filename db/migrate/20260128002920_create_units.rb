class CreateUnits < ActiveRecord::Migration[7.2]
  def change
    create_table :units do |t|
      t.string :name
      t.references :company, null: true, foreign_key: true
      t.boolean :custom, default: true

      t.timestamps
    end
  end
end
