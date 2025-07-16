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
    @invoice = current_user.invoices.build(invoice_params.except(:line_items_attributes))

    if params[:invoice][:line_items_attributes].present?
      @invoice.line_items_data = params[:invoice][:line_items_attributes].values
    end

    if @invoice.save
      redirect_to invoices_path, notice: "Invoice created successfully."
    else
      render :new
    end
  end


  private

  def invoice_params
    params.require(:invoice).permit(
      :invoice_number,
      :issue_date,
      :currency,
      :payment_due_date,
      :delivery_date,
      :recipient_company_id,
      :message,
      :footer_notes,
      :save_notes_for_future,
      :save_footer_notes_for_future,
      :save_payment_terms_for_future,
      :attachment,

      # delivery details...
      :delivery_details_postbox,
      :delivery_details_street,
      :delivery_details_number,
      :delivery_details_locality_name,
      :delivery_details_zip_code,
      :delivery_details_city,
      :delivery_details_country,
      :delivery_details_gln,
      :delivery_details_company_name,
      :delivery_details_tax_id,
      :delivery_details_tax_number,

      # bank details...
      :bank_name,
      :bank_sort_code,
      :bank_account_number,
      :bank_account_holder,
      :bank_street_name,
      :bank_builder_number,
      :bank_city,
      :bank_zip_code,
      :bank_region,
      :bank_address_line,
      :bank_country,
      :bank_payment_note,

      # invoice headers...
      :header_type,
      :header_description,
      :header_qty,
      :header_unit,
      :header_tax,
      :header_total,
      :pricing_discount,

      # Accept a dynamic hash for line items
      line_items_attributes: {}
    )
  end
end
