class CreateCompanies < ActiveRecord::Migration[7.2]
  def change
    create_table :companies do |t|
      t.string :name
      t.string :website
      t.string :industry
      t.string :ownership
      t.string :address
      t.string :phone
      t.text   :description
      t.string :size
      t.string :share_capital
      t.string :registration_address
      t.string :email_address
      t.string :company_id_type
      t.string :tax_id_type
      t.string :gln
      t.string :company_id_number
      t.string :tax_id_number
      t.string :internal_identifier
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
  end
end