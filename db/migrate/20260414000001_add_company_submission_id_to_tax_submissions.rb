class AddCompanySubmissionIdToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_column :tax_submissions, :company_submission_id, :integer
    add_index :tax_submissions, [:company_id, :company_submission_id]
  end
end
