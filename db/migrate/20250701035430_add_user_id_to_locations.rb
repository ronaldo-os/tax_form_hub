class AddUserIdToLocations < ActiveRecord::Migration[7.2]
  def change
    add_reference :locations, :user, null: false, foreign_key: true
  end
end
