# frozen_string_literal: true

class PriceAdjustmentItemWrapper
  attr_reader :invoice, :adjustment, :index
  alias_method :item, :adjustment

  def initialize(invoice, adjustment, index)
    @invoice = invoice
    @adjustment = adjustment || {}
    @index = index
  end

  def id
    @invoice.id
  end

  def to_param
    @invoice.to_param
  end

  def to_key
    [@invoice.id, @index]
  end

  def persisted?
    @invoice.persisted?
  end

  def model_name
    @invoice.model_name
  end

  def subscription_active?
    extract_status == 'active'
  end

  def subscription_cancelled?
    extract_status == 'cancelled'
  end

  def subscription_finished?
    extract_status == 'finished'
  end

  def description
    @adjustment['description_edit'].presence || @adjustment['description'].presence || "Price Adjustment"
  end

  def billing_cycle
    freq = @adjustment['frequency'] || @adjustment[:frequency]
    case freq.to_s
    when 'annually', 'yearly' then 'annual'
    else 'monthly'
    end
  end

  def type_label
    adj_type = @adjustment['type'] || @adjustment[:type] || @adjustment['unit'] || @adjustment[:unit] || 'Adjustment'
    adj_type.to_s.capitalize
  end

  def amount_val
    (@adjustment['amount'] || @adjustment[:amount]).to_f
  end

  def unit_val
    unit = @adjustment['unit'] || @adjustment[:unit]
    unit == '%' ? '%' : ((@invoice.currency.presence || 'PHP') + ' ')
  end

  def respond_to_missing?(method_name, include_private = false)
    return false if method_name == :to_ary
    @invoice.respond_to?(method_name, include_private) || super
  end

  def method_missing(method_name, *args, &block)
    return super if method_name == :to_ary
    if @invoice.respond_to?(method_name)
      @invoice.public_send(method_name, *args, &block)
    else
      super
    end
  end

  private

  def extract_status
    if @invoice.subscription_cancelled? || @invoice.archived?
      return 'cancelled'
    end

    if @adjustment['cancelled'] || @adjustment[:cancelled] || @adjustment.dig('optional_fields', 'cancelled')
      return 'cancelled'
    end

    end_date_val = @adjustment['charge_end_date'] || @adjustment[:charge_end_date]
    if end_date_val.present?
      begin
        end_d = Date.parse(end_date_val.to_s)
        if end_d < Date.current
          return 'finished'
        end
      rescue Date::Error
      end
    end

    start_date_val = @adjustment['charge_start_date'] || @adjustment[:charge_start_date] || @invoice.issue_date&.to_s
    if start_date_val.present? && end_date_val.present?
      begin
        start_d = Date.parse(start_date_val.to_s)
        end_d = Date.parse(end_date_val.to_s)
        if start_d && end_d && start_d < end_d
          cycle = billing_cycle
          count = 0
          curr = start_d
          while curr < end_d
            curr = @invoice.calculate_next_period_date(curr, cycle)
            count += 1
          end
          if count > 1 && @invoice.recurring_sub_invoices.count >= (count - 1)
            return 'finished'
          end
        end
      rescue Date::Error
      end
    end

    'active'
  end
end
