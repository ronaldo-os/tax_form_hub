# frozen_string_literal: true

module SubscriptionsHelper
  # Returns the allowed bulk action keys for a subscription or price adjustment
  # based on the actions available in its row dropdown.
  def allowed_subscription_bulk_actions(record)
    return [] unless record

    actions = []
    is_active = if record.respond_to?(:subscription_active?)
                  record.subscription_active?
                else
                  false
                end

    actions << "cancel" if is_active
    actions
  end
end
