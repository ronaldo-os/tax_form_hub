class CreateNetworks < ActiveRecord::Migration[7.2]
  def change
    create_table :networks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
    add_index :networks, [:user_id, :company_id], unique: true
  end
end
