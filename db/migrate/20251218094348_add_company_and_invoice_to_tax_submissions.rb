class AddCompanyAndInvoiceToTaxSubmissions < ActiveRecord::Migration[7.2]
  def change
    add_reference :tax_submissions, :company, null: false, foreign_key: true
    add_reference :tax_submissions, :invoice, null: false, foreign_key: true
  end
end
