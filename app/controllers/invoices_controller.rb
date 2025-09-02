class InvoicesController < ApplicationController
  def index
    @invoices_sale = current_user.invoices.where(invoice_type: "sale", archived: false).order(issue_date: :desc)
    @invoices_sale_archived = current_user.invoices.where(invoice_type: "sale", archived: true).order(issue_date: :desc)
    @invoices_purchase = current_user.invoices.where(invoice_type: "purchase", archived: false).order(issue_date: :desc)
    @invoices_purchase_archived = current_user.invoices.where(invoice_type: "purchase", archived: true).order(issue_date: :desc)
  end

  def show
    @invoice = Invoice.find(params[:id])
    @recipient_company = @invoice.recipient_company
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = current_user.locations.group_by(&:location_type)

    @ship_from_location = Location.find(@invoice.ship_from_location_id) if @invoice.ship_from_location_id.present?
    @remit_to_location_id = Location.find(@invoice.remit_to_location_id) if @invoice.remit_to_location_id.present?
    @tax_representative_location_id = Location.find(@invoice.tax_representative_location_id) if @invoice.tax_representative_location_id.present?
  end

  def new
    @invoice = Invoice.new
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = Location.all.group_by(&:location_type)

    # Get most recent invoice of current_user
    last_invoice = Invoice.where(user_id: current_user.id).order(created_at: :desc).first

    if last_invoice
      @recipient_note = last_invoice.recipient_note if last_invoice.save_notes_for_future
      @footer_notes = last_invoice.footer_notes if last_invoice.save_footer_notes_for_future
      @payment_terms = last_invoice.payment_terms if last_invoice.save_payment_terms_for_future
    end
  end

  def edit
    @invoice = current_user.invoices.find(params[:id])
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = current_user.locations.group_by(&:location_type)
  end

  def create
    clean_params = invoice_params.deep_dup
    clean_params.delete(:line_items_attributes)

    # Normalize JSON fields
    normalize_json_fields!(clean_params)

    @invoice = current_user.invoices.build(clean_params)
    @invoice.invoice_type ||= "sale"
    @invoice.status ||= "draft"

    if params[:invoice][:line_items_attributes].present?
      processed_items = params[:invoice][:line_items_attributes].values.map do |line_item|
        line_item[:optional_fields] = process_optional_fields(line_item[:optional_fields]) if line_item[:optional_fields].present?
        line_item
      end
      @invoice.line_items_data = processed_items
    end

    if @invoice.save
      redirect_to invoices_path, notice: "Invoice created successfully."
    else
      render :new
    end
  end

  def update
    @invoice = current_user.invoices.find(params[:id])

    # Handle removing attachments
    if params[:invoice][:remove_attachment_ids].present?
      params[:invoice][:remove_attachment_ids].each do |attach_id|
        attachment = @invoice.attachments.find_by(id: attach_id)
        attachment&.purge
      end
    end

    clean_params = invoice_params.deep_dup
    clean_params.delete(:attachments)

    # Normalize JSON fields
    normalize_json_fields!(clean_params)

    if clean_params[:line_items_attributes].present?
      processed_items = clean_params[:line_items_attributes].values.map do |line_item|
        if line_item[:optional_fields].present?
          line_item[:optional_fields] = process_optional_fields(line_item[:optional_fields])
        end
        line_item
      end
      @invoice.line_items_data = processed_items
      clean_params.delete(:line_items_attributes)
    end

    # Handle new attachments
    if params[:invoice][:attachments].present?
      params[:invoice][:attachments].each do |attachment|
        @invoice.attachments.attach(attachment)
      end
    end

    if @invoice.update(clean_params)
      redirect_to invoice_path(@invoice), notice: "Invoice updated successfully."
    else
      render :edit
    end
  end

  def create_and_send
    clean_params = invoice_params.deep_dup
    clean_params.delete(:line_items_attributes)

    # Normalize JSON fields
    normalize_json_fields!(clean_params)

    @invoice = current_user.invoices.build(clean_params)
    @invoice.invoice_type ||= "sale"
    @invoice.status = "sent"

    if params[:invoice][:line_items_attributes].present?
      processed_items = params[:invoice][:line_items_attributes].values.map do |line_item|
        line_item[:optional_fields] = process_optional_fields(line_item[:optional_fields]) if line_item[:optional_fields].present?
        line_item
      end
      @invoice.line_items_data = processed_items
    end

    if @invoice.save
      recipient_company_id = @invoice.recipient_company_id
      recipient_user = Company.find_by(id: recipient_company_id)&.user

      unless recipient_user
        redirect_to invoice_path(@invoice), alert: "Recipient user not found." and return
      end

      duplicated_invoice = @invoice.dup
      duplicated_invoice.assign_attributes(
        user_id: recipient_user.id,
        sale_from_id: @invoice.id,
        status: "pending",
        invoice_type: "purchase"
      )

      if duplicated_invoice.save
        redirect_to invoices_path, notice: "Invoice sent successfully"
      else
        redirect_to invoices_path, alert: "Invoice created, but failed to send to recipient."
      end
    else
      render :new
    end
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

    unless recipient_user
      redirect_to invoice_path(original), alert: "Recipient user not found." and return
    end

    duplicated_invoice = original.dup
    duplicated_invoice.assign_attributes(
      user_id: recipient_user.id,
      sale_from_id: original.id,
      status: "pending",
      invoice_type: "purchase"
    )

    if duplicated_invoice.save
      original.update(status: "sent")
      redirect_to invoices_path, notice: "Invoice duplicated as purchase."
    else
      redirect_to invoices_path, alert: "Failed to duplicate invoice."
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

  def process_optional_fields(fields)
    grouped = {}
    fields.each do |flat_key, data|
      next unless flat_key.include?(".")
      parts = flat_key.split(".")
      group_key = parts[0]
      field_key = parts[1..].join(".")

      grouped[group_key] ||= {}
      grouped[group_key][field_key] = data
    end
    grouped
  end

  def normalize_json_fields!(clean_params)
    %w[payment_terms price_adjustments invoice_info total].each do |field|
      next unless clean_params.key?(field)

      raw = clean_params[field]

      clean_params[field] =
        case raw
        when String
          begin
            JSON.parse(raw.gsub(/=>/, ':'))
          rescue JSON::ParserError
            Rails.logger.warn "Invalid JSON for #{field}: #{raw.inspect}"
            {}
          end
        when Hash, ActionController::Parameters
          raw.to_unsafe_h
        else
          raw
        end
    end
  end

  def update_original_sale_status(purchase_invoice, status)
    return unless purchase_invoice.sale_from_id.present?
    original_sale_invoice = Invoice.find_by(id: purchase_invoice.sale_from_id, invoice_type: "sale")
    original_sale_invoice&.update(status: status)
  end

  def invoice_params
    permitted = params.require(:invoice).permit(
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
        :item_id, :description, :quantity, :unit, :price, :tax, :total,
        { optional_fields: {} }
      ]
    )

    # Convert blank or zero location IDs to nil
    %i[ship_from_location_id remit_to_location_id tax_representative_location_id].each do |field|
      permitted[field] = nil if permitted[field].blank? || permitted[field].to_i.zero?
    end

    permitted
  end
end
