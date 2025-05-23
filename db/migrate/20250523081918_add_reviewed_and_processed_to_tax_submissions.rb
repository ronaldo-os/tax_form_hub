class AddReviewedAndProcessedToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :tax_submissions, :reviewed, :boolean
    add_column :tax_submissions, :processed, :boolean
  end
end
