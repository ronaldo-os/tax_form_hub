# frozen_string_literal: true

class Payment < ApplicationRecord
  PAYMENT_METHODS = [
    "Bank Transfer",
    "Check",
    "GCash",
    "Maya"
  ].freeze

  belongs_to :invoice
  belongs_to :user

  validates :payment_method, presence: true, inclusion: {
    in: PAYMENT_METHODS,
    message: "%{value} is not a valid payment method. Choose from: #{PAYMENT_METHODS.join(', ')}"
  }
  validates :reference_number, presence: true, length: { maximum: 100 }
  validates :payment_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }

  validate :amount_cannot_exceed_remaining_balance, on: :create

  scope :recent, -> { order(payment_date: :desc, created_at: :desc) }

  def formatted_amount
    sym = invoice&.currency_symbol || "₱"
    "#{sym} #{sprintf('%.2f', amount.to_f)}"
  end

  def payment_method_icon
    case payment_method
    when "Bank Transfer" then "fa-solid fa-building-columns"
    when "Check"         then "fa-solid fa-money-check"
    when "GCash"         then "fa-solid fa-mobile-screen-button"
    when "Maya"          then "fa-solid fa-wallet"
    else                      "fa-solid fa-receipt"
    end
  end

  def payment_method_badge_class
    case payment_method
    when "Bank Transfer" then "bg-primary-subtle text-primary border border-primary-subtle"
    when "Check"         then "bg-secondary-subtle text-secondary border border-secondary-subtle"
    when "GCash"         then "bg-info-subtle text-info border border-info-subtle"
    when "Maya"          then "bg-success-subtle text-success border border-success-subtle"
    else                      "bg-light text-dark"
    end
  end

  private

  def amount_cannot_exceed_remaining_balance
    return unless invoice && amount.present? && amount.to_f > 0

    already_paid = invoice.payments.where.not(id: id).sum(:amount).to_f
    max_allowed = (invoice.grand_total - already_paid).round(2)

    if max_allowed > 0 && amount.to_f > (max_allowed + 0.001)
      errors.add(:amount, "cannot exceed the remaining balance of #{invoice.currency_symbol} #{sprintf('%.2f', max_allowed)}")
    end
  end
end
