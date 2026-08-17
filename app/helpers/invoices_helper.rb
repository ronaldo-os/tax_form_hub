module InvoicesHelper
  def format_invoice_date(value)
    return '—' if value.blank?

    date_obj = case value
               when Date, Time, DateTime
                 value
               when String
                 Date.parse(value) rescue nil
               else
                 nil
               end

    return value.to_s if date_obj.nil?

    date_obj.strftime("%b %d, %Y")
  end

  def invoice_display_quantity(item)
    subscription = item.dig("optional_fields", "subscription")
    quantity = extract_optional_subscription_field(subscription, "quantity")
    return quantity if quantity.present?

    item["quantity"]
  end

  def invoice_company_number(company)
    company&.company_id_number.presence || company&.internal_identifier.presence || company&.gln.presence || '-'
  end

  def invoice_tax_number(company)
    company&.tax_id_number.presence || company&.gln.presence || '-'
  end

  def invoice_form_page_title(invoice)
    if invoice&.quote?
      "Create New Quote"
    elsif invoice&.credit_note?
      "Create New Credit Note"
    else
      "Create New Invoice"
    end
  end

  def edit_invoice_page_title(invoice)
    if invoice&.quote?
      "Edit Quote"
    elsif invoice&.credit_note?
      "Edit Credit Note"
    else
      "Edit Invoice"
    end
  end

  def show_invoice_page_title(invoice)
    prefix = if invoice&.quote?
               "Quote: "
             elsif invoice&.credit_note?
               "Credit Note: "
             else
               "Invoice: "
             end
    "#{prefix}#{invoice&.invoice_number}"
  end

  private

  def extract_optional_subscription_field(subscription, field_name)
    return nil unless subscription.is_a?(Hash)

    if subscription.key?(field_name)
      value = subscription[field_name]
      return value.to_s.strip if value.present?
    end

    key = subscription.keys.find { |k| k.to_s.include?(field_name) }
    value = subscription[key] if key
    value.to_s.strip if value.present?
  end
end
