# frozen_string_literal: true

module MailerHelper
  EMAIL_ACCENTS = {
    primary: {
      bar: "#00aeff",
      badge_bg: "#e0f2fe",
      badge_border: "#bae6fd",
      badge_text: "#0369a1",
      button_bg: "#00aeff"
    },
    success: {
      bar: "#10b981",
      badge_bg: "#ecfdf5",
      badge_border: "#a7f3d0",
      badge_text: "#047857",
      button_bg: "#00aeff"
    },
    warning: {
      bar: "#f59e0b",
      badge_bg: "#fffbeb",
      badge_border: "#fde68a",
      badge_text: "#b45309",
      button_bg: "#00aeff"
    },
    danger: {
      bar: "#dc2626",
      badge_bg: "#fef2f2",
      badge_border: "#fecaca",
      badge_text: "#b91c1c",
      button_bg: "#dc2626"
    }
  }.freeze

  CALLOUT_TONES = {
    neutral: {
      bg: "#f8fafc",
      border: "#cbd5e1",
      accent: "#64748b",
      title: "#334155",
      text: "#334155"
    },
    info: {
      bg: "#f0f9ff",
      border: "#bae6fd",
      accent: "#00aeff",
      title: "#0369a1",
      text: "#0c4a6e"
    },
    warning: {
      bg: "#fffbeb",
      border: "#fde68a",
      accent: "#f59e0b",
      title: "#92400e",
      text: "#78350f"
    },
    danger: {
      bg: "#fef2f2",
      border: "#fecaca",
      accent: "#dc2626",
      title: "#991b1b",
      text: "#b91c1c"
    }
  }.freeze

  CURRENCY_SYMBOLS = {
    "PHP" => "₱",
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "JPY" => "¥"
  }.freeze

  def email_accent_palette(key = :primary)
    EMAIL_ACCENTS.fetch(key.to_s.to_sym, EMAIL_ACCENTS[:primary])
  end

  def email_callout_palette(tone = :neutral)
    CALLOUT_TONES.fetch(tone.to_s.to_sym, CALLOUT_TONES[:neutral])
  end

  def email_currency_symbol(currency)
    code = currency.to_s.upcase
    CURRENCY_SYMBOLS[code] || code.presence || "₱"
  end

  def email_format_amount(amount, currency)
    "#{email_currency_symbol(currency)}#{number_with_precision(amount.to_f, precision: 2, delimiter: ',')}"
  end

  def email_duration_label(duration)
    total_seconds = duration.to_i
    return "a limited time" if total_seconds <= 0

    if (total_seconds % 1.day.to_i).zero?
      days = total_seconds / 1.day.to_i
      "#{days} #{days == 1 ? 'day' : 'days'}"
    elsif (total_seconds % 1.hour.to_i).zero?
      hours = total_seconds / 1.hour.to_i
      "#{hours} #{hours == 1 ? 'hour' : 'hours'}"
    elsif (total_seconds % 1.minute.to_i).zero?
      minutes = total_seconds / 1.minute.to_i
      "#{minutes} #{minutes == 1 ? 'minute' : 'minutes'}"
    else
      "#{total_seconds} #{total_seconds == 1 ? 'second' : 'seconds'}"
    end
  end

  def email_expiration_timestamp(expires_at)
    return nil unless expires_at.respond_to?(:strftime)

    expires_at.in_time_zone.strftime("%b %d, %Y at %I:%M %p %Z")
  end
end
