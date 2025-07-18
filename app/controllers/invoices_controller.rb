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
      :user_id,
      :recipient_company_id,
      :invoice_number,
      :issue_date,
      :currency,
      :recipient_note,
      :message,
      :footer_notes,
      :save_notes_for_future,
      :save_footer_notes_for_future,
      :save_payment_terms_for_future,

      # delivery details
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

      # location references
      :ship_from_location_id,
      :remit_to_location_id,
      :tax_representative_location_id,

      # JSON fields (expected to be handled via hidden inputs or JS)
      :line_items_data,
      :payment_terms,
      :header_charge_discount_tax,
      :price_adjustments,
      # line items and their optional fields...
      line_items_attributes: [
        :item_id, :description, :quantity, :unit, :price, :tax, :recurring, :_destroy,
        { optional_fields: {} }
      ]
    )
  end


end
