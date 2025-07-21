class RemoveHeaderChargeDiscountTaxFromInvoices < ActiveRecord::Migration[6.1] # or your current version
  def change
    remove_column :invoices, :header_charge_discount_tax, :jsonb
  end
end
