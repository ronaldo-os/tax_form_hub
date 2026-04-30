# frozen_string_literal: true

# Handles server-side processing for Invoice DataTables
# Reduces initial page load by loading data via AJAX
#
class InvoiceDatatable < BaseDatatable
  # Sortable columns mapping to database columns
  SORTABLE_COLUMNS = {
    0 => 'invoices.invoice_number',
    1 => 'companies.name',
    2 => 'invoices.total',
    3 => 'invoices.issue_date',
    5 => 'invoices.status'
  }.freeze

  # Searchable columns
  SEARCHABLE_COLUMNS = [
    'invoices.invoice_number',
    'companies.name',
    'invoices.status'
  ].freeze

  def initialize(view, current_user, options = {})
    super(view, current_user)
    @invoice_type = options[:invoice_type]
    @archived = options[:archived]
    @quote = options[:quote]
  end

  def records_total
    base_scope.distinct.count(:id)
  end

  def records_filtered
    filtered_scope.distinct.count(:id)
  end

  def data
    paginate(filtered_scope).map do |invoice|
      {
        'DT_RowId' => "invoice_#{invoice.id}",
        'invoice_number' => invoice_link(invoice),
        'counterparty' => counterparty_name(invoice),
        'total' => format_total(invoice),
        'issue_date' => format_date(invoice.issue_date),
        'attachments' => format_attachments(invoice),
        'status' => format_status(invoice),
        'actions' => format_actions(invoice)
      }
    end
  end

  private

  def base_scope
    scope = current_user.invoices
      .includes(:recipient_company, :sale_from)
      .with_attached_attachments
      .where(archived: @archived)

    if @quote
      scope = scope.where(invoice_category: 'quote')
    else
      scope = scope.where.not(invoice_category: 'quote')
    end

    scope = scope.where(invoice_type: @invoice_type) if @invoice_type.present?

    # Default ordering by most recent first
    scope.order(issue_date: :desc, created_at: :desc)
  end

  def filtered_scope
    scope = base_scope

    # Apply search if provided
    if search_value.present?
      scope = scope.left_joins(:recipient_company, :sale_from)
      scope = apply_search(scope, SEARCHABLE_COLUMNS)
    end

    # Apply ordering - default to most recent first
    scope = apply_order(scope, SORTABLE_COLUMNS)

    # Ensure we get distinct invoices (avoid duplicates from joins)
    scope.distinct
  end

  def invoice_link(invoice)
    badges = []

    if invoice.credit_note?
      badges << '<span class="badge badge_cn ms-1">CN</span>'
    elsif invoice.has_associated_credit_note?
      badges << '<span class="badge badge_has_cn ms-1">Has CN</span>'
    end

    link_to(invoice.invoice_number, url_helpers.invoice_path(invoice, tab: active_tab)) + badges.join
  end

  def counterparty_name(invoice)
    name = if @invoice_type == 'purchase' || is_purchase_table?
      invoice.sale_from&.name || '—'
    else
      invoice.recipient_company&.name || '—'
    end

    content_tag(:div, truncate(name, length: 30), class: 'text-truncate', title: name)
  end

  def format_total(invoice)
    currency = invoice.currency || 'PHP'
    amount = number_with_precision(invoice.total.to_h['grand_total'].to_f, precision: 2, delimiter: ',')
    "#{currency} #{amount}"
  end

  def format_date(date)
    date&.strftime('%b %d, %Y') || '—'
  end

  def format_attachments(invoice)
    if invoice.attachments.attached?
      button = content_tag(:button, 'View Files',
        class: 'btn btn-sm btn-outline-primary',
        data: {
          'bs-toggle' => 'modal',
          'bs-target' => "#attachmentModal-#{invoice.id}"
        }
      )

      # Build modal HTML for attachments
      # Use view's url_for which has access to the request host
      modal_content = invoice.attachments.map do |file|
        file_url = view.url_for(file)
        if file.content_type.to_s.start_with?("image/")
          content_tag(:div, class: 'col-md-6 mb-3') do
            link_to(file_url, target: "_blank") do
              tag.img(src: file_url, class: 'img-fluid rounded border', alt: 'Attachment', loading: 'lazy')
            end
          end
        elsif file.content_type.to_s == 'application/pdf'
          content_tag(:div, class: 'col-md-6 mb-3') do
            content_tag(:div, class: 'd-flex align-items-center justify-content-between border p-2 rounded') do
              concat(content_tag(:span, file.filename.to_s))
              concat(link_to('View PDF', view.url_for(file), target: '_blank', class: 'btn btn-sm btn-outline-secondary'))
            end
          end
        else
          content_tag(:div, class: 'col-md-6 mb-3') do
            content_tag(:div, class: 'border p-2 rounded') do
              concat(content_tag(:span, file.filename.to_s))
              concat(link_to('Download', file_url, class: 'btn btn-sm btn-outline-secondary', target: '_blank'))
            end
          end
        end
      end.join

      modal = content_tag(:div, class: 'modal fade', id: "attachmentModal-#{invoice.id}", tabindex: '-1', 'aria-labelledby': "attachmentModalLabel-#{invoice.id}", 'aria-hidden': 'true') do
        content_tag(:div, class: 'modal-dialog modal-md modal-dialog-scrollable') do
          content_tag(:div, class: 'modal-content') do
            header = content_tag(:div, class: 'modal-header border-0') do
              title = content_tag(:h5, 'Attachments', class: 'modal-title', id: "attachmentModalLabel-#{invoice.id}")
              close_btn = content_tag(:button, '', type: 'button', class: 'btn-close', data: { 'bs-dismiss': 'modal' }, 'aria-label': 'Close')
              title + close_btn
            end
            body = content_tag(:div, class: 'modal-body') do
              content_tag(:div, class: 'row') do
                modal_content.html_safe
              end
            end
            header + body
          end
        end
      end

      button + modal
    else
      content_tag(:span, 'No File', class: 'text-muted')
    end
  end

  def format_status(invoice)
    if invoice.quote? && invoice.invoice_type == 'purchase' && invoice.status == 'sent'
      'Received'
    else
      invoice.status.to_s.capitalize
    end
  end

  def format_actions(invoice)
    content_tag(:div, class: 'dropdown text-center') do
      button = content_tag(:button, '&#8942;'.html_safe,
        class: 'btn btn-link text-muted p-0 text-decoration-none fs-3',
        type: 'button',
        id: "actionsDropdown_#{invoice.id}",
        data: { 'bs-toggle' => 'dropdown' },
        'aria-expanded' => 'false'
      )

      menu_items = build_action_items(invoice)
      menu = content_tag(:ul, menu_items.html_safe, class: 'dropdown-menu', 'aria-labelledby' => "actionsDropdown_#{invoice.id}")

      button + menu
    end
  end

  def build_action_items(invoice)
    items = []

    # Preview
    items << content_tag(:li) do
      link_to('Preview', '#', class: 'dropdown-item preview-invoice', data: { id: invoice.id })
    end

    items << content_tag(:li, '', class: 'dropdown-divider')

    # Download PDF
    items << content_tag(:li) do
      link_to('Download PDF', '#', class: 'dropdown-item download-pdf', data: { id: invoice.id })
    end

    # Edit (draft only)
    if invoice.status == 'draft'
      items << content_tag(:li) do
        link_to('Edit', url_helpers.edit_invoice_path(invoice, tab: active_tab), class: 'dropdown-item')
      end
      items << content_tag(:li, '', class: 'dropdown-divider')
    end

    # Use as Draft
    if invoice.status != 'draft' && !is_purchase_table?
      items << content_tag(:li) do
        link_to('Use as Draft',
          url_helpers.new_invoice_path(template_id: invoice.id, tab: active_tab),
          class: 'dropdown-item')
      end
    end

    # Mark as Paid
    if %w[approved sent].include?(invoice.status) && !is_received_quotes_table?
      items << content_tag(:li) do
        link_to('Mark as Paid',
          url_helpers.mark_as_paid_invoice_path(invoice, tab: active_tab),
          method: :patch,
          data: { confirm: 'Mark this invoice as paid?' },
          class: 'dropdown-item')
      end
    end

    # Create Credit Note
    if invoice.standard? && invoice.invoice_type == 'sale' && %w[sent approved paid].include?(invoice.status)
      items << content_tag(:li) do
        link_to('Create Credit Note',
          url_helpers.new_invoice_path(original_invoice_id: invoice.id, category: 'credit_note', tab: active_tab),
          class: 'dropdown-item')
      end
    end

    items << content_tag(:li, '', class: 'dropdown-divider') if items.size > 5

    # Archive/Unarchive
    unless invoice.has_associated_credit_note?
      action = invoice.archived? ? 'Unarchive' : 'Archive'
      path = invoice.archived? ?
        url_helpers.unarchive_invoice_path(invoice, tab: active_tab) :
        url_helpers.archive_invoice_path(invoice, tab: active_tab)

      items << content_tag(:li) do
        link_to(action, path,
          method: :patch,
          data: { confirm: "#{action} this invoice?" },
          class: invoice.archived? ? 'dropdown-item' : 'dropdown-item')
      end
    end

    # Delete (draft only)
    if invoice.status == 'draft'
      items << content_tag(:li) do
        link_to('Delete',
          url_helpers.invoice_path(invoice, tab: active_tab),
          method: :delete,
          data: { confirm: 'Are you sure you want to delete this invoice?' },
          class: 'dropdown-item text-danger')
      end
    end

    items.join.html_safe
  end

  def active_tab
    params[:tab] || 'sales-invoices'
  end

  def is_purchase_table?
    active_tab&.include?('purchase')
  end

  def is_received_quotes_table?
    active_tab&.include?('received-quotes')
  end
end
