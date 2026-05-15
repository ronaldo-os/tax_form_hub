# frozen_string_literal: true

# Service for calculating prorated discounts for mid-cycle account additions
class ProrationService
  CYCLE_DAYS = {
    'monthly' => 30,
    'quarterly' => 90,
    'annual' => 365
  }.freeze

  # Calculate prorated discount for mid-cycle account additions
  #
  # @param accounts_added [Integer] Number of accounts added
  # @param activation_date [Date] Date when accounts were activated
  # @param billing_cycle [String] Billing cycle type (monthly, quarterly, annual)
  # @param unit_price [Float] Full price per account for the cycle
  # @param cycle_start [Date] Start date of the current billing cycle
  # @param renewal_date [Date] End date of the current billing cycle
  # @return [Hash] Contains pro_rated_price, discount_amount, remaining_days, cycle_days
  def self.calculate_proration(accounts_added:, activation_date:, billing_cycle:, unit_price:, cycle_start:, renewal_date:)
    return nil if accounts_added.nil? || accounts_added.to_s.empty? ||
                  activation_date.nil? || billing_cycle.nil? || billing_cycle.to_s.empty? ||
                  unit_price.nil? || unit_price.to_s.empty? ||
                  cycle_start.nil? || renewal_date.nil?

    accounts = accounts_added.to_i
    return nil if accounts <= 0

    cycle_start_date = cycle_start.to_date
    renewal_date = renewal_date.to_date
    activation_date = activation_date.to_date

    # Ensure we use the actual billing cycle length between start and renewal
    cycle_days = (renewal_date - cycle_start_date).to_i
    return zero_result if cycle_days <= 0

    # Proration should only apply for the time from activation until the renewal within the same cycle
    effective_start = [activation_date, cycle_start_date].max
    remaining_days = (renewal_date - effective_start).to_i
    remaining_days = 0 if remaining_days < 0

    return zero_result if remaining_days <= 0

    full_price = unit_price.to_f * accounts
    prorated_ratio = remaining_days.to_f / cycle_days
    pro_rated_price = full_price * prorated_ratio
    discount_amount = full_price - pro_rated_price

    {
      pro_rated_price: pro_rated_price.round(2),
      discount_amount: discount_amount.round(2),
      remaining_days: remaining_days,
      cycle_days: cycle_days,
      full_price: full_price.round(2),
      accounts_added: accounts
    }
  end

  # Calculate proration from subscription_addition optional fields
  #
  # @param subscription_addition [Hash] The optional_fields data for subscription_addition
  # @param subscription [Hash] The optional_fields data for subscription (contains billing_cycle, renewal_date)
  # @param unit_price [Float] Price per unit from the main line item
  # @return [Hash] Proration calculation result
  def self.calculate_from_optional_fields(subscription_addition:, subscription:, unit_price:)
    return nil if subscription_addition.nil? || subscription_addition.empty? || subscription.nil? || subscription.empty?

    accounts_added = extract_field_value(subscription_addition, 'accounts_added')
    activation_date = extract_field_value(subscription_addition, 'activation_date')
    billing_cycle = extract_field_value(subscription, 'billing_cycle')
    cycle_start = extract_field_value(subscription, 'start_date')
    renewal_date = extract_field_value(subscription, 'renewal_date')

    calculate_proration(
      accounts_added: accounts_added,
      activation_date: parse_date(activation_date),
      billing_cycle: billing_cycle,
      unit_price: unit_price.to_f,
      cycle_start: parse_date(cycle_start),
      renewal_date: parse_date(renewal_date)
    )
  end

  # Batch calculate prorations for all subscription_addition entries in an invoice
  #
  # @param line_items [Array<Hash>] Array of line item data
  # @return [Array<Hash>] Array of proration results with line item references
  def self.calculate_invoice_prorations(line_items)
    return [] if line_items.nil? || line_items.empty?

    results = []

    # Find all base subscriptions and their additions
    subscriptions = find_base_subscriptions(line_items)
    subscription_additions = find_subscription_additions_across_line_items(line_items)

    # Group additions by their base subscription reference
    additions_by_subscription = group_additions_by_subscription(subscription_additions)

    subscriptions.each do |subscription_data|
      subscription = subscription_data[:subscription]
      line_item_index = subscription_data[:line_item_index]
      item = line_items[line_item_index]

      # Find additions for this subscription
      subscription_id = item['item_id']
      additions = additions_by_subscription[subscription_id] || []

      next if additions.empty?

      unit_price = item['price'].to_f

      additions.each do |addition|
        proration = calculate_from_optional_fields(
          subscription_addition: addition[:fields],
          subscription: subscription,
          unit_price: unit_price
        )

        if proration
          # Extract activation date for display
          activation_date_value = extract_field_value(addition[:fields], 'activation_date')
          activation_date = parse_date(activation_date_value)

          results << proration.merge(
            line_item_index: line_item_index,
            line_item_id: item['item_id'],
            line_item_description: item['description'],
            addition_line_item_index: addition[:line_item_index],
            addition_line_item_id: addition[:line_item_id],
            addition_group_key: addition[:group_key],
            activation_date: activation_date
          )
        end
      end
    end

    results
  end

  # Generate discount description for display
  #
  # @param accounts_added [Integer] Number of accounts
  # @param activation_date [Date] Activation date
  # @return [String] Formatted description
  def self.generate_discount_description(accounts_added:, activation_date:)
    date_str = activation_date.is_a?(Date) ? activation_date.strftime('%B %d, %Y') : activation_date.to_s
    pluralized = accounts_added == 1 ? 'Account' : 'Accounts'
    "#{accounts_added} #{pluralized} Activated #{date_str}"
  end

  # Build complete discount breakdown for an invoice
  #
  # @param line_items [Array<Hash>] Array of line item data
  # @return [Hash] Hash mapping line item indices to their discount breakdowns
  def self.build_discount_breakdown(line_items)
    prorations = calculate_invoice_prorations(line_items)

    breakdown = {}
    prorations.each do |proration|
      index = proration[:line_item_index]
      breakdown[index] ||= []
      breakdown[index] << {
        description: generate_discount_description(
          accounts_added: proration[:accounts_added],
          activation_date: proration[:activation_date] || Date.today
        ),
        discount_amount: proration[:discount_amount],
        remaining_days: proration[:remaining_days],
        cycle_days: proration[:cycle_days],
        accounts_added: proration[:accounts_added]
      }
    end

    breakdown
  end

  class << self
    private

    def zero_result
      {
        pro_rated_price: 0.0,
        discount_amount: 0.0,
        remaining_days: 0,
        cycle_days: 30,
        full_price: 0.0,
        accounts_added: 0
      }
    end

    def extract_field_value(fields, field_name)
      return nil if fields.nil? || fields.empty?

      # Try exact match first
      return fields[field_name] if fields.key?(field_name)

      # Try partial match on key names (handles the nested naming format like "subscription_addition.accounts_added")
      # Match both patterns: "field_name.suffix" and just containing field_name
      key = fields.keys.find do |k|
        k_str = k.to_s
        k_str == field_name ||
          k_str.start_with?("#{field_name}.") ||
          k_str.include?("#{field_name}")
      end
      fields[key] if key && !key.empty?
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.is_a?(Time) || value.is_a?(DateTime)
      return Date.parse(value) if value.is_a?(String) && !value.empty?
      nil
    rescue ArgumentError
      nil
    end

    def find_subscription_additions(optional_fields)
      return [] if optional_fields.nil? || optional_fields.empty?

      additions = []

      optional_fields.each do |group_key, fields|
        if group_key.to_s.start_with?('subscription_addition')
          additions << { group_key: group_key, fields: fields }
        end
      end

      additions
    end

    def find_base_subscriptions(line_items)
      subscriptions = []

      line_items.each_with_index do |item, index|
        next unless item['optional_fields'] && item['optional_fields']['subscription']

        subscription = item['optional_fields']['subscription']
        next if subscription.empty?

        subscriptions << {
          subscription: subscription,
          line_item_index: index,
          line_item_id: item['item_id']
        }
      end

      subscriptions
    end

    def find_subscription_additions_across_line_items(line_items)
      additions = []

      line_items.each_with_index do |item, index|
        next unless item['optional_fields']

        item['optional_fields'].each do |group_key, fields|
          if group_key.to_s.start_with?('subscription_addition')
            # Extract base subscription reference from the addition fields
            base_subscription_id = extract_field_value(fields, 'base_subscription_id')
            if base_subscription_id.blank?
              # Fallback: try to extract from item description or use the item_id as fallback
              base_subscription_id = item['item_id'].to_s.gsub(/-addition$/, '') if item['item_id']
            end

            additions << {
              group_key: group_key,
              fields: fields,
              line_item_index: index,
              line_item_id: item['item_id'],
              base_subscription_id: base_subscription_id
            }
          end
        end
      end

      additions
    end

    def group_additions_by_subscription(subscription_additions)
      grouped = {}

      subscription_additions.each do |addition|
        base_id = addition[:base_subscription_id]
        grouped[base_id] ||= []
        grouped[base_id] << addition
      end

      grouped
    end
  end
end
