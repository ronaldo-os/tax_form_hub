class PasswordComplexityValidator < ActiveModel::EachValidator
  COMMON_PASSWORDS = %w[
    password password123 password123! Password123 Password123!
    welcome welcome123 welcome123! Welcome123 Welcome123!
    admin admin123 admin123! Admin123 Admin123!
    qwerty 123456789 1234567890 letmein123
  ].freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    unless value.length >= 12
      record.errors.add(attribute, "must be at least 12 characters long.")
    end

    unless value.match?(/[A-Z]/)
      record.errors.add(attribute, "must contain at least one uppercase letter.")
    end

    unless value.match?(/[a-z]/)
      record.errors.add(attribute, "must contain at least one lowercase letter.")
    end

    unless value.match?(/[0-9]/)
      record.errors.add(attribute, "must contain at least one number.")
    end

    unless value.match?(/[^A-Za-z0-9]/)
      record.errors.add(attribute, "must contain at least one special character.")
    end

    if COMMON_PASSWORDS.include?(value.downcase)
      record.errors.add(attribute, "is too common. Please choose a more secure password.")
    end

    if record.respond_to?(:email) && record.email.present?
      email_local_part = record.email.split('@').first
      if value.downcase.include?(record.email.downcase) || value.downcase.include?(email_local_part.downcase)
        record.errors.add(attribute, "cannot contain your email address.")
      end
    end
  end
end
