# frozen_string_literal: true

class CurrencyConverter
  # Base currency is USD (rates relative to 1.0 USD)
  RATES = {
    "USD" => 1.0,
    "PHP" => 57.0,
    "EUR" => 0.92,
    "GBP" => 0.79,
    "JPY" => 155.0,
    "SGD" => 1.35,
    "CAD" => 1.37,
    "AUD" => 1.52
  }.freeze

  def self.convert(amount, from:, to:)
    return 0.0 if amount.nil?
    amount_num = amount.to_f
    return 0.0 if amount_num.zero?

    from_curr = normalize_currency(from)
    to_curr = normalize_currency(to)

    return amount_num if from_curr == to_curr

    from_rate = RATES[from_curr] || 1.0
    to_rate = RATES[to_curr] || 1.0

    amount_in_usd = amount_num / from_rate
    (amount_in_usd * to_rate).round(2)
  end

  def self.rate(from, to)
    from_curr = normalize_currency(from)
    to_curr = normalize_currency(to)
    from_rate = RATES[from_curr] || 1.0
    to_rate = RATES[to_curr] || 1.0
    (to_rate / from_rate).round(4)
  end

  private

  def self.normalize_currency(currency_code)
    code = currency_code.to_s.upcase.strip
    RATES.key?(code) ? code : "PHP"
  end
end
