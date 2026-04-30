# frozen_string_literal: true

# Base class for DataTables server-side processing
# Subclasses should implement:
#   - records_total: Total count of all records
#   - records_filtered: Count of records after filtering
#   - data: Array of records for current page
#
class BaseDatatable
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  attr_reader :view, :params, :current_user

  def initialize(view, current_user)
    @view = view
    @current_user = current_user
    @params = view.params
  end

  # Total records count (unfiltered)
  def records_total
    raise NotImplementedError
  end

  # Filtered records count
  def records_filtered
    raise NotImplementedError
  end

  # Array of data for current page
  def data
    raise NotImplementedError
  end

  protected

  def page_start
    params[:start].to_i
  end

  def page_length
    [(params[:length] || 25).to_i, 100].min
  end

  def search_value
    params.dig(:search, :value)
  end

  def order_params
    params[:order] || { '0' => { 'column' => '0', 'dir' => 'desc' } }
  end

  # Apply search to relation
  def apply_search(relation, searchable_columns)
    return relation if search_value.blank?

    conditions = searchable_columns.map do |column|
      "#{column} ILIKE ?"
    end.join(' OR ')

    relation.where(conditions, *Array.new(searchable_columns.size, "%#{search_value}%"))
  end

  # Apply pagination
  def paginate(relation)
    relation.limit(page_length).offset(page_start)
  end

  # Apply ordering
  def apply_order(relation, sortable_columns)
    order_params.each do |_, order|
      column_index = order['column'].to_i
      direction = order['dir'] == 'asc' ? 'ASC' : 'DESC'

      column = sortable_columns[column_index]
      relation = relation.order(Arel.sql("#{column} #{direction}")) if column.present?
    end

    relation
  end

  def url_helpers
    Rails.application.routes.url_helpers
  end

  def content_tag(*args, &block)
    view.content_tag(*args, &block)
  end

  def link_to(*args, &block)
    view.link_to(*args, &block)
  end

  def number_with_precision(*args)
    view.number_with_precision(*args)
  end

  def truncate(*args)
    view.truncate(*args)
  end

  def tag
    view.tag
  end
end
