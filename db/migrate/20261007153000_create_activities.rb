class CreateActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :activities do |t|
      t.references :trackable, polymorphic: true, null: false, index: true
      t.references :user, foreign_key: true, index: true
      t.string :user_name
      t.string :user_email
      t.string :action, null: false
      t.text :description
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :activities, [:trackable_type, :trackable_id, :created_at], name: "index_activities_on_trackable_and_created_at"
    add_index :activities, :action
  end
end
