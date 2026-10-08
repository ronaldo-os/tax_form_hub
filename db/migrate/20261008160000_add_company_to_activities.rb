# frozen_string_literal: true

class AddCompanyToActivities < ActiveRecord::Migration[7.2]
  def change
    add_reference :activities, :company, foreign_key: true, index: true, null: true
    add_column :activities, :company_name, :string
  end
end
