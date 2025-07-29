class InvoicesController < ApplicationController
  def index
    @invoices_sale = Invoice.where(user_id: current_user.id, invoice_type: "sale", archived: false).order(issue_date: :desc)
    @invoices_sale_archived = Invoice.where(user_id: current_user.id, invoice_type: "sale", archived: true).order(issue_date: :desc)

    @invoices_purchase = Invoice.where(user_id: current_user.id, invoice_type: "purchase", archived: false).order(issue_date: :desc)
    @invoices_purchase_archived = Invoice.where(user_id: current_user.id, invoice_type: "purchase", archived: true).order(issue_date: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
    @recipient_company = @invoice.recipient_company
    @locations_by_type = Location.where(user_id: current_user.id).group_by(&:location_type)

    @ship_from_location = Location.find(@invoice.ship_from_location_id) if @invoice.ship_from_location_id.present?
    @remit_to_location_id = Location.find(@invoice.remit_to_location_id) if @invoice.remit_to_location_id.present?
    @tax_representative_location_id = Location.find(@invoice.tax_representative_location_id) if @invoice.tax_representative_location_id.present?
  end

  def new
    @invoice = Invoice.new
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = Location.all.group_by(&:location_type)
  end

  def destroy
    @invoice = Invoice.find(params[:id])
    @invoice.destroy
    redirect_to invoices_path, notice: "Invoice deleted successfully."
  end

  def duplicate_as_purchase
    original = Invoice.find(params[:id])

    recipient_company_id = original.recipient_company_id
    recipient_user = Company.find_by(id: recipient_company_id)&.user

    if recipient_user.nil?
      redirect_to invoice_path(original), alert: "Recipient user not found."
      return
    end

    duplicated_invoice = original.dup
    duplicated_invoice.user_id = recipient_user.id
    duplicated_invoice.sale_from_id = original.id
    duplicated_invoice.status = "pending"
    duplicated_invoice.invoice_type = "purchase"

    if duplicated_invoice.save
      original.update(status: "sent")
      redirect_to invoices_path, notice: "Invoice duplicated as purchase."
    else
      redirect_to invoices_path, alert: "Failed to duplicate invoice."
    end
  end

  def create
    clean_params = invoice_params.deep_dup
    clean_params.delete(:line_items_attributes)

    @invoice = current_user.invoices.build(clean_params)
    @invoice.invoice_type ||= "sale"
    @invoice.status ||= "draft"

    if params[:invoice][:line_items_attributes].present?
      @invoice.line_items_data = params[:invoice][:line_items_attributes].values
    end

      %i[
        payment_terms
        price_adjustments
        invoice_info
        total
      ].each do |field|
        raw_value = params[:invoice][field]
        if raw_value.present?
          begin
            @invoice.send("#{field}=", JSON.parse(raw_value))
          rescue JSON::ParserError
            @invoice.send("#{field}=", [])
          end
        end
      end

      if @invoice.save
        redirect_to invoices_path, notice: "Invoice created successfully."
      else
        render :new
      end
  end

  def approve
    invoice = current_user.invoices.find(params[:id])

    if invoice.update(status: "approved")
      update_original_sale_status(invoice, "approved")
      redirect_to invoices_path, notice: "Invoice approved."
    else
      redirect_to invoices_path, alert: "Failed to approve invoice."
    end
  end

  def deny
    invoice = current_user.invoices.find(params[:id])

    if invoice.update(status: "denied")
      update_original_sale_status(invoice, "denied")
      redirect_to invoices_path, notice: "Invoice denied."
    else
      redirect_to invoices_path, alert: "Failed to deny invoice."
    end
  end

  def archive
    invoice = current_user.invoices.find(params[:id])
    invoice.update(archived: true)
    redirect_to invoices_path, notice: "Invoice archived."
  end

  def unarchive
    invoice = current_user.invoices.find(params[:id])
    invoice.update(archived: false)
    redirect_to invoices_path, notice: "Invoice unarchived."
  end


  def mark_as_paid
    sale_invoice = current_user.invoices.find(params[:id])

    if sale_invoice.update(status: "paid")
      purchase_invoice = Invoice.find_by(sale_from_id: sale_invoice.id, invoice_type: "purchase")
      purchase_invoice&.update(status: "paid")

      redirect_to invoices_path, notice: "Invoice marked as paid."
    else
      redirect_to invoices_path, alert: "Failed to update invoice."
    end
  end

  private

  def update_original_sale_status(purchase_invoice, status)
    return unless purchase_invoice.sale_from_id.present?
    original_sale_invoice = Invoice.find_by(id: purchase_invoice.sale_from_id, invoice_type: "sale")
    original_sale_invoice&.update(status: status)
  end


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
      :invoice_type,

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

      # JSON fields
      :line_items_data,
      :payment_terms,
      :price_adjustments,
      :invoice_info,
      :total,

      # attachments
      attachments: [],

      # nested line items
      line_items_attributes: [
        :item_id, :description, :quantity, :unit, :price, :tax, :recurring, :_destroy,
        { optional_fields: {} }
      ]
    )
  end
end
