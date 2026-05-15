module InvoicesHelper
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
