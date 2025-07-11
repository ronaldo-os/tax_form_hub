class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.order(issue_date: :desc)
  end

  def new
    @invoice = Invoice.new
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = Location.all.group_by(&:location_type)
  end


  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      redirect_to invoices_path, notice: 'Invoice was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def invoice_params
    params.require(:invoice).permit(
      :invoice_number, :issue_date, :currency, :payment_due_date,
      :item_id, :description, :quantity, :unit, :price_per_unit, :tax, :total,
      :recipient_note, :header_type, :header_description, :header_qty, :header_unit,
      :header_tax, :header_total, :pricing_discount,
      :bank_name, :bank_sort_code, :bank_account_number, :bank_account_holder,
      :bank_street_name, :bank_builder_number, :bank_city, :bank_zip_code,
      :bank_region, :bank_addresss_line, :bank_country, :bank_payment_note,
      :attachment, :recipient_company_id
    )
  end
end
