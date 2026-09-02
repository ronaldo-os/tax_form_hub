class AddCurrencyToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :currency, :string, default: "PHP"
  end
end
