# frozen_string_literal: true

# Provides server-side processing support for DataTables
# Reduces initial page load by loading data via AJAX instead of rendering all rows server-side
#
# Usage:
#   class InvoicesController < ApplicationController
#     include DatatablesServerSide
#   end
#
#   def index
#     respond_to do |format|
#       format.html
#       format.json { render_datatable_json(InvoiceDatatable.new(view_context)) }
#     end
#   end
#
module DatatablesServerSide
  extend ActiveSupport::Concern

  # Default page length for DataTables
  DEFAULT_PAGE_LENGTH = 25

  # Maximum allowed page length to prevent abuse
  MAX_PAGE_LENGTH = 100

  # Renders JSON response for DataTables server-side processing
  # @param datatable [Object] Datatable object that responds to #data, #records_filtered, #records_total
  def render_datatable_json(datatable)
    render json: {
      draw: params[:draw].to_i,
      recordsTotal: datatable.records_total,
      recordsFiltered: datatable.records_filtered,
      data: datatable.data
    }
  rescue StandardError => e
    Rails.logger.error "DataTables error: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: {
      draw: params[:draw].to_i,
      recordsTotal: 0,
      recordsFiltered: 0,
      data: [],
      error: Rails.env.development? ? "#{e.class}: #{e.message}" : "Server error loading data"
    }, status: 500
  end

  # Extracts DataTables parameters from request
  def datatable_params
    {
      draw: params[:draw],
      start: params[:start].to_i,
      length: [params[:length].to_i, MAX_PAGE_LENGTH].min,
      search_value: params.dig(:search, :value),
      order: parse_order_params,
      columns: params[:columns] || {}
    }
  end

  private

  def parse_order_params
    return [] unless params[:order]

    params[:order].map do |_, order|
      column_index = order[:column].to_i
      column_name = params.dig(:columns, column_index.to_s, :data)
      direction = order[:dir] == 'asc' ? :asc : :desc

      { column: column_name, direction: direction } if column_name.present?
    end.compact
  end
end
