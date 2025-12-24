class AddUserTransactionIdToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :tax_submissions, :user_transaction_id, :integer
    add_index :tax_submissions, [:email, :user_transaction_id]
  end
end
