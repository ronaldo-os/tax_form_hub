class InvoicesController < ApplicationController
  def index
    @invoices_sale = current_user.invoices.where(invoice_type: "sale", archived: false).order(issue_date: :desc)
    @invoices_sale_archived = current_user.invoices.where(invoice_type: "sale", archived: true).order(issue_date: :desc)
    @invoices_purchase = current_user.invoices.where(invoice_type: "purchase", archived: false).order(issue_date: :desc)
    @invoices_purchase_archived = current_user.invoices.where(invoice_type: "purchase", archived: true).order(issue_date: :desc)

    # month ranges (use Time.current so it respects time zone)
    current_month_range = Time.current.beginning_of_month..Time.current.end_of_month
    last_month_range    = 1.month.ago.beginning_of_month..1.month.ago.end_of_month

    # Summary stats
    @invoice_totals_sale     = build_invoice_stats(@invoices_sale, current_month_range, last_month_range)
    @invoice_totals_purchase = build_invoice_stats(@invoices_purchase, current_month_range, last_month_range)

    # Trend graph data (last 6 months)
    @invoice_trends_sale     = build_invoice_trends(@invoices_sale)
    @invoice_trends_purchase = build_invoice_trends(@invoices_purchase)

    @active_tab = params[:tab] || 'sales'
  end


  def show
    @invoice = Invoice.find(params[:id])
    @recipient_company = @invoice.recipient_company
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = current_user.locations.group_by(&:location_type)

    @ship_from_location = Location.find(@invoice.ship_from_location_id) if @invoice.ship_from_location_id.present?
    @remit_to_location_id = Location.find(@invoice.remit_to_location_id) if @invoice.remit_to_location_id.present?
    @tax_representative_location_id = Location.find(@invoice.tax_representative_location_id) if @invoice.tax_representative_location_id.present?

    respond_to do |format|
      format.html
      format.json { render json: @invoice } # keep JSON if you want
      format.js   # optional if you want a JS template
      format.any(:pdf, :html) do
        render partial: "invoices/partials/invoice_card", locals: { invoice: @invoice }
      end
    end
  end


  def new
    @recipient_companies = Company.where.not(user_id: current_user.id)
    @locations_by_type = Location.all.group_by(&:location_type)

    if params[:template_id].present?
      template = Invoice.find(params[:template_id])

      @invoice = Invoice.new(
        template.attributes.except("id", "created_at", "updated_at", "status", "invoice_number", "user_id")
      )

      @invoice.user_id = current_user.id
      @invoice.status = "draft"
      @invoice.invoice_type ||= "sale"

      @invoice.line_items_data = template.line_items_data if template.line_items_data.present?

      # Flags for template case → copy values directly
      @save_payment_terms_for_future = template.save_payment_terms_for_future
      @save_notes_for_future         = template.save_notes_for_future
      @save_footer_notes_for_future  = template.save_footer_notes_for_future

    else
      @invoice = Invoice.new
      last_invoice = Invoice.where(user_id: current_user.id).order(created_at: :desc).first
      if last_invoice
        @recipient_note = last_invoice.recipient_note if last_invoice.save_notes_for_future
        @footer_notes   = last_invoice.footer_notes   if last_invoice.save_footer_notes_for_future
        @payment_terms  = last_invoice.payment_terms  if last_invoice.save_payment_terms_for_future

        @save_payment_terms_for_future = last_invoice.save_payment_terms_for_future
        @save_notes_for_future         = last_invoice.save_notes_for_future
        @save_footer_notes_for_future  = last_invoice.save_footer_notes_for_future
      else
        @save_payment_terms_for_future = false
        @save_notes_for_future         = false
        @save_footer_notes_for_future  = false
      end
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

    # Process line items
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

    # Handle payment terms JSON edit
    if clean_params[:payment_terms_json_edit].present?
      @invoice.payment_terms_data = JSON.parse(clean_params[:payment_terms_json_edit]) rescue {}
      clean_params.delete(:payment_terms_json_edit)
    end

    # Handle new attachments
    if params[:invoice][:attachments].present?
      params[:invoice][:attachments].each do |attachment|
        @invoice.attachments.attach(attachment)
      end
    end

    if @invoice.update(clean_params)
      if params[:commit_action] == "send"
        @invoice.update(status: "sent")

        recipient_user = Company.find_by(id: @invoice.recipient_company_id)&.user
        InvoiceMailer.invoice_sent(@invoice, recipient_user).deliver_later if recipient_user

        redirect_to invoice_path(@invoice), notice: "Invoice sent successfully."
      else
        redirect_to invoice_path(@invoice), notice: "Invoice updated successfully."
      end
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
        @invoice.attachments.each do |attachment|
          duplicated_invoice.attachments.attach(
            io: StringIO.new(attachment.download),
            filename: attachment.filename.to_s,
            content_type: attachment.content_type
          )
        end
        InvoiceMailer.invoice_sent(duplicated_invoice, recipient_user).deliver_later
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
    original = current_user.invoices.find(params[:id])

    clean_params = invoice_params.deep_dup
    clean_params.delete(:attachments)

    # Normalize JSON fields
    normalize_json_fields!(clean_params)

    # Process line items
    if clean_params[:line_items_attributes].present?
      processed_items = clean_params[:line_items_attributes].values.map do |line_item|
        if line_item[:optional_fields].present?
          line_item[:optional_fields] = process_optional_fields(line_item[:optional_fields])
        end
        line_item
      end
      original.line_items_data = processed_items
      clean_params.delete(:line_items_attributes)
    end

    # Handle payment terms JSON edit
    if clean_params[:payment_terms_json_edit].present?
      original.payment_terms_data = JSON.parse(clean_params[:payment_terms_json_edit]) rescue {}
      clean_params.delete(:payment_terms_json_edit)
    end

    # Handle attachments
    if params[:invoice][:attachments].present?
      params[:invoice][:attachments].each do |attachment|
        original.attachments.attach(attachment)
      end
    end

    if original.update(clean_params)
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
        # Mark both as sent
        duplicated_invoice.update(status: "sent")
        original.update(status: "sent")

        InvoiceMailer.invoice_sent(duplicated_invoice, recipient_user).deliver_later
        redirect_to invoice_path(original), notice: "Invoice sent successfully."
      else
        redirect_to invoices_path, alert: "Failed to duplicate invoice."
      end
    else
      render :edit
    end
  end

  def approve
    invoice = current_user.invoices.find(params[:id])
    if invoice.update(status: "approved")
      update_original_sale_status(invoice, "approved")
      redirect_to invoices_path(tab: "purchases"), notice: "Invoice approved."
    else
      redirect_to invoices_path(tab: "purchases"), alert: "Failed to approve invoice."
    end
  end

  def deny
    invoice = current_user.invoices.find(params[:id])
    if invoice.update(status: "denied")
      update_original_sale_status(invoice, "denied")
      redirect_to invoices_path(tab: "purchases"), notice: "Invoice denied."
    else
      redirect_to invoices_path(tab: "purchases"), alert: "Failed to deny invoice."
    end
  end

  def archive
    invoice = current_user.invoices.find(params[:id])
    invoice.update(archived: true)
    tab = invoice.invoice_type == "purchase" ? "purchases" : "sales"
    redirect_to invoices_path(tab: tab), notice: "Invoice archived."
  end

  def unarchive
    invoice = current_user.invoices.find(params[:id])
    invoice.update(archived: false)
    tab = invoice.invoice_type == "purchase" ? "purchases" : "sales"
    redirect_to invoices_path(tab: tab), notice: "Invoice unarchived."
  end

  def mark_as_paid
    sale_invoice = current_user.invoices.find(params[:id])
    if sale_invoice.update(status: "paid")
      purchase_invoice = Invoice.find_by(sale_from_id: sale_invoice.id, invoice_type: "purchase")
      purchase_invoice&.update(status: "paid")
      tab = sale_invoice.invoice_type == "purchase" ? "purchases" : "sales"
      redirect_to invoices_path(tab: tab), notice: "Invoice marked as paid."
    else
      tab = sale_invoice.invoice_type == "purchase" ? "purchases" : "sales"
      redirect_to invoices_path(tab: tab), alert: "Failed to update invoice."
    end
  end

  private

  def build_invoice_trends(relation)
    statuses = %w[total draft sent paid pending]
    trends = {}

    6.times.reverse_each do |i|
      month_start = i.months.ago.beginning_of_month
      month_end   = i.months.ago.end_of_month
      label       = month_start.strftime("%b")

      month_scope = relation.where(issue_date: month_start..month_end)

      statuses.each do |status|
        count =
          if status == "total"
            month_scope.count
          else
            month_scope.where(status: status).count
          end

        trends[status] ||= []
        trends[status] << { month: label, count: count }
      end
    end

    trends
  end

  def build_invoice_stats(relation, current_range, last_range)
    statuses = %w[draft sent paid pending]
    stats = {}

    (["total"] + statuses).each do |status|
      if status == "total"
        overall = relation.count
        current = relation.where(issue_date: current_range).count
        last    = relation.where(issue_date: last_range).count
      else
        overall = relation.where(status: status).count
        current = relation.where(status: status, issue_date: current_range).count
        last    = relation.where(status: status, issue_date: last_range).count
      end

      percent_change =
        if last.zero?
          current.positive? ? 100.0 : 0.0
        else
          (((current - last).to_f / last) * 100).round(1)
        end

      stats[status] = {
        "overall"        => overall,
        "current"        => current,
        "last"           => last,
        "percent_change" => percent_change
      }
    end

    stats
  end

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
