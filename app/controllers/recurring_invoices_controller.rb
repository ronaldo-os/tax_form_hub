class RecurringInvoicesController < ApplicationController
  before_action :find_invoice_and_line_item, only: [:update, :destroy, :disable, :enable]

  def index
    @recurring_items = []
    @disabled_recurring_items = []

    current_user.invoices.find_each do |invoice|
      invoice.line_items_data.each_with_index do |item, index|
        recurring = recurring_fields(item)
        next unless recurring

        base_item = {
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
          interval: recurring["interval.select(daily,weekly,monthly,yearly).2"]
        }

        if recurring["recurring.select(yes,no).2"] == "yes"
          @recurring_items << base_item
        elsif recurring["recurring.select(yes,no).2"] == "no"
          @disabled_recurring_items << base_item
        end
      end
    end
    fresh_when etag: current_user.invoices, last_modified: current_user.invoices.maximum(:updated_at)
  end

  def update
    recurring_fields = @line_item["optional_fields"]["recurring"]
    recurring_fields["recurring.select(yes,no).2"] = params[:mode]
    recurring_fields["interval.select(daily,weekly,monthly,yearly).2"] = params[:interval]
    recurring_fields["every.number.2"] = params[:every]
    recurring_fields["start_date.date.2"] = params[:start_date]
    recurring_fields["end_date.date.2"] = params[:end_date]

    save_invoice_changes

    flash[:notice] = "Recurring settings updated."
    respond_to_flash_success
  end

  def enable
    rf = recurring_fields(@line_item)
    unless rf
      flash[:alert] = "Recurring fields not found."
      return respond_to_flash_error
    end

    rf["recurring.select(yes,no).2"] = "yes"
    save_invoice_changes

    flash[:notice] = "Recurring item enabled."
    respond_to_flash_success
  end

  def disable
    rf = recurring_fields(@line_item)
    unless rf
      flash[:alert] = "Recurring fields not found."
      return respond_to_flash_error
    end

    rf["recurring.select(yes,no).2"] = "no"
    save_invoice_changes

    flash[:notice] = "Recurring item disabled."
    respond_to_flash_success
  end

  def destroy
    idx = params[:line_index].to_i
    if @invoice.line_items_data[idx] &&
       @invoice.line_items_data[idx]["optional_fields"] &&
       @invoice.line_items_data[idx]["optional_fields"]["recurring"]

      @invoice.line_items_data[idx]["optional_fields"].delete("recurring")
      save_invoice_changes

      flash[:notice] = "Recurring data deleted."
      respond_to_flash_success
    else
      flash[:alert] = "No recurring data found."
      respond_to_flash_error
    end
  end

  private

  def find_invoice_and_line_item
    invoice_id = params[:invoice_id] || params[:id]
    @invoice   = current_user.invoices.find(invoice_id)

    if params[:line_index].present?
      @line_item = @invoice.line_items_data[params[:line_index].to_i]
    end
  end

  def save_invoice_changes
    @invoice.update!(line_items_data: @invoice.line_items_data)
  end

  def recurring_fields(item)
    return nil unless item.is_a?(Hash)
    item.dig("optional_fields", "recurring")
  end

  def recurring_params
    params.permit(
      :description, :quantity, :unit, :price, :total,
      :start_date, :end_date, :every, :interval
    )
  end

  # Helpers for consistent flash + response
  def respond_to_flash_success
    respond_to do |format|
      format.json { head :ok }
      format.html { redirect_to recurring_invoices_path }
    end
  end

  def respond_to_flash_error
    respond_to do |format|
      format.json { head :unprocessable_entity }
      format.html { redirect_to recurring_invoices_path }
    end
  end
end
