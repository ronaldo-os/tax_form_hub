class RecurringInvoicesController < ApplicationController
  def index
    @recurring_items = []

    Invoice.find_each do |invoice|
      invoice.line_items_data.each_with_index do |item, index|
        recurring = item.dig("optional_fields", "recurring")
        next unless recurring && recurring["mode.select(yes,no).2"] == "yes"

        @recurring_items << {
          invoice_id: invoice.id,
          invoice_number: invoice.invoice_number,
          line_index: index,
          description: item["description"],
          quantity: item["quantity"],
          unit: item["unit"],
          price: item["price"],
          total: item["total"],
          start_date: recurring["start_date.date.2"],
          end_date: recurring["end_date.date.2"],
          every: recurring["every.number.2"],
          interval: recurring["interval.select(daily,weekly,monthly,yearly).2"],
          count: recurring["count.number.2"]
        }
      end
    end
  end
end
