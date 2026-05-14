class CreateSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipient_company, foreign_key: { to_table: :companies }, null: true
      t.references :sale_from_company, foreign_key: { to_table: :companies }, null: true

      # Core subscription lifecycle
      t.date :start_date, null: false
      t.date :end_date, null: true
      t.string :status, default: 'active', null: false
      t.string :billing_cycle, null: false # 'monthly', 'quarterly', 'annual'

      # Current billing period
      t.date :current_period_start, null: false
      t.date :current_period_end, null: false
      t.date :next_invoice_date, null: false

      # Pricing
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: 'USD'

      # Invoice details
      t.string :description, null: true
      t.jsonb :line_item_data, default: {}, null: false

      # Renewal tracking
      t.datetime :last_invoice_generated_at, null: true
      t.integer :renewal_count, default: 0, null: false

      # Metadata
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :subscriptions, [:user_id, :status]
    add_index :subscriptions, [:user_id, :next_invoice_date]
    add_index :subscriptions, :next_invoice_date
    add_index :subscriptions, [:recipient_company_id, :status]
    add_index :subscriptions, [:user_id, :created_at]
  end
end
