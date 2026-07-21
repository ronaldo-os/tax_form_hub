class SubscriptionItemWrapper
  attr_reader :invoice, :item, :index

  def initialize(invoice, item, index)
    @invoice = invoice
    @item = item
    @index = index
  end

  def subscription_active?
    status = extract_status
    status == 'active'
  end

  def subscription_cancelled?
    status = extract_status
    status == 'cancelled'
  end

  def subscription_finished?
    status = extract_status
    status == 'finished'
  end

  def total_amount
    qty = (@item['quantity'] || 1).to_s.delete(',').to_f
    prc = @item['price'].to_s.delete(',').to_f
    tx = @item['tax'].to_s.delete(',').to_f
    total = qty * prc * (1 + tx / 100.0)

    first_sub_index = (@invoice.line_items_data || []).index do |i|
      i.is_a?(Hash) && i['optional_fields'].is_a?(Hash) && i['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') } && !i.dig('optional_fields', 'hidden_on_parent')
    end

    (@invoice.line_items_data || []).each do |sub_item|
      next unless sub_item.is_a?(Hash)
      opt = sub_item['optional_fields'] || {}
      
      is_recurring_mid_cycle = opt['hidden_on_parent'] && opt.keys.any? { |k| k.to_s.start_with?('subscription') }
      next unless is_recurring_mid_cycle

      parent_idx = opt['parent_item_index']
      expected_parent_idx = parent_idx.present? ? parent_idx.to_i : first_sub_index
      
      if expected_parent_idx == @index && !opt['cancelled']
        s_qty = (sub_item['quantity'] || 1).to_s.delete(',').to_f
        s_prc = sub_item['price'].to_s.delete(',').to_f
        s_tx = sub_item['tax'].to_s.delete(',').to_f
        total += s_qty * s_prc * (1 + s_tx / 100.0)
      end
    end
    
    total
  end

  private

  def extract_status
    if @invoice.subscription_cancelled?
      return 'cancelled'
    end

    optional_fields = @item['optional_fields'] || {}
    sub_fields = optional_fields['subscription'] || {}
    
    if optional_fields['cancelled']
      return 'cancelled'
    end

    end_date_str = sub_fields.keys.find { |k| k.to_s.include?('end_date') }
    end_date_val = sub_fields[end_date_str] if end_date_str

    if end_date_val.present?
      begin
        end_date = Date.parse(end_date_val)
        if end_date < Date.current
          return 'finished'
        end
      rescue Date::Error
      end
    end

    'active'
  end
end
