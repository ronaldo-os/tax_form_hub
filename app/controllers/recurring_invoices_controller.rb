class RecurringInvoicesController < ApplicationController
  before_action :find_invoice_and_line_item, only: [:update, :destroy, :disable]

  def index
    @recurring_items = []

    Invoice.find_each do |invoice|
      invoice.line_items_data.each_with_index do |item, index|
        recurring = recurring_fields(item)
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

  def update
    recurring_fields = @line_item["optional_fields"]["recurring"]
    recurring_fields["mode.select(yes,no).2"] = params[:mode]
    recurring_fields["interval.select(daily,weekly,monthly,yearly).2"] = params[:interval]
    recurring_fields["every.number.2"] = params[:every]
    recurring_fields["start_date.date.2"] = params[:start_date]
    recurring_fields["end_date.date.2"] = params[:end_date]
    recurring_fields["count.number.2"] = params[:count]

    save_invoice_changes

    flash[:notice] = "Recurring settings updated."
    flash.keep(:notice)

    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_to recurring_invoices_path, notice: "Recurring settings updated." }
    end
  end

  def disable
    recurring_fields(@line_item)["mode.select(yes,no).2"] = "no"
    save_invoice_changes

    respond_to do |format|
      format.html { redirect_to recurring_invoices_path, notice: "Recurring item disabled." }
      format.json { render json: { success: true } }
    end
  end

  def destroy
    @invoice.line_items_data.delete_at(params[:line_index].to_i)
    save_invoice_changes

    respond_to do |format|
      format.html { redirect_to recurring_invoices_path, notice: "Recurring item deleted." }
      format.json { render json: { success: true } }
    end
  end

  private

  def find_invoice_and_line_item
    @invoice = Invoice.find(params[:invoice_id])
    @line_item = @invoice.line_items_data[params[:line_index].to_i]
  end

  def save_invoice_changes
    @invoice.update!(line_items_data: @invoice.line_items_data)
  end

  def recurring_fields(item)
    item.dig("optional_fields", "recurring")
  end

  def recurring_params
    params.permit(
      :description, :quantity, :unit, :price, :total,
      :start_date, :end_date, :every, :interval
    )
  end
end
