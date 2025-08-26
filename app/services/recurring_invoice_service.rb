class RecurringInvoiceService
  def self.run
    Rails.logger.info "Recurring invoice service Starting..."

    recurring_invoices = Invoice.where(recurring_origin_invoice_id: nil).select do |invoice|
      has_recurring = invoice.line_items.any? do |item|
        recurring = item.dig("optional_fields", "recurring")
        next false unless recurring

        next false unless recurring["recurring.select(yes,no).2"] == "yes"

        start_date = Date.parse(recurring["start_date.date.2"]) rescue nil
        end_date   = Date.parse(recurring["end_date.date.2"]) rescue nil
        every      = recurring["every.number.2"].to_i
        interval   = recurring["interval.select(daily,weekly,monthly,yearly).2"]

        next false unless start_date
        next false if Date.today < start_date
        next false if end_date && Date.today > end_date

        every = 1 if every <= 0

        case interval
        when "daily"
          (Date.today - start_date).to_i % every == 0
        when "weekly"
          ((Date.today - start_date).to_i / 7) % every == 0
        when "monthly"
          months_between = (Date.today.year * 12 + Date.today.month) - (start_date.year * 12 + start_date.month)
          months_between % every == 0 && Date.today.day == start_date.day
        when "yearly"
          years_between = Date.today.year - start_date.year
          years_between % every == 0 && Date.today.yday == start_date.yday
        else
          false
        end
      end

      has_recurring
    end

    if recurring_invoices.empty?
      Rails.logger.info "No recurring invoices found to process."
      Rails.logger.info "Recurring invoice service Done."
      return
    end

    recurring_invoices.each do |invoice|
      Rails.logger.info "Recurring invoice service Processing Invoice ##{invoice.invoice_number}"

      new_invoice_number = next_invoice_number
      new_issue_date = Date.today

      new_invoice = Invoice.create!(
        user: invoice.user,
        recipient_company_id: invoice.recipient_company_id,
        invoice_number: new_invoice_number,
        issue_date: new_issue_date,
        line_items_data: invoice.line_items_data,
        payment_terms: invoice.payment_terms,
        price_adjustments: invoice.price_adjustments,
        recipient_note: invoice.recipient_note,
        delivery_details_country: invoice.delivery_details_country,
        delivery_details_postbox: invoice.delivery_details_postbox,
        delivery_details_street: invoice.delivery_details_street,
        delivery_details_number: invoice.delivery_details_number,
        delivery_details_locality_name: invoice.delivery_details_locality_name,
        delivery_details_zip_code: invoice.delivery_details_zip_code,
        delivery_details_city: invoice.delivery_details_city,
        delivery_details_gln: invoice.delivery_details_gln,
        delivery_details_company_name: invoice.delivery_details_company_name,
        delivery_details_tax_id: invoice.delivery_details_tax_id,
        delivery_details_tax_number: invoice.delivery_details_tax_number,
        ship_from_location_id: invoice.ship_from_location_id,
        remit_to_location_id: invoice.remit_to_location_id,
        tax_representative_location_id: invoice.tax_representative_location_id,
        message: invoice.message,
        footer_notes: invoice.footer_notes,
        save_notes_for_future: invoice.save_notes_for_future,
        save_footer_notes_for_future: invoice.save_footer_notes_for_future,
        save_payment_terms_for_future: invoice.save_payment_terms_for_future,
        invoice_info: invoice.invoice_info,
        total: invoice.total,
        invoice_type: invoice.invoice_type,
        status: "draft",
        recurring_origin_invoice_id: invoice.id
      )

      Rails.logger.info "Recurring invoice service Created new invoice ##{new_invoice_number} (child of ##{invoice.invoice_number})"
    end

    Rails.logger.info "Recurring invoice service Done."
  end

  private

  def self.next_invoice_number
    last_number = Invoice.order(:id).pluck(:invoice_number).compact.last

    if last_number =~ /\d+$/
      prefix = last_number.gsub(/\d+$/, "")
      num = last_number.match(/(\d+)$/)[1].to_i + 1
      "#{prefix}#{num.to_s.rjust(3, '0')}"
    else
      "#{last_number}-001"
    end
  end
end
