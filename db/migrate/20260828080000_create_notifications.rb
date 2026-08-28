class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }, index: true
      t.references :actor, foreign_key: { to_table: :users }, index: true
      t.references :notifiable, polymorphic: true, index: true
      t.string :category, null: false, default: "invoices"
      t.string :action, null: false
      t.string :title, null: false
      t.text :message
      t.string :target_url
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:recipient_id, :read_at]
    add_index :notifications, [:recipient_id, :category]
    add_index :notifications, [:recipient_id, :created_at]
  end
end
