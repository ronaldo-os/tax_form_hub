# frozen_string_literal: true

class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :payment_method, null: false
      t.string :reference_number, null: false
      t.date :payment_date, null: false
      t.text :notes

      t.timestamps
    end

    add_index :payments, [:invoice_id, :payment_date]
  end
end
