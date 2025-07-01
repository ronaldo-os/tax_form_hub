class AddUserIdToCompanies < ActiveRecord::Migration[7.0]
  def change
    add_reference :companies, :user, foreign_key: true
  end
end
