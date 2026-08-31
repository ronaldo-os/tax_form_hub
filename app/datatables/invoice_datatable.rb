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
    'sale_froms_invoices.name',
    'invoices.status'
  ].freeze

  def initialize(view, current_user, options = {})
    super(view, current_user)
    @invoice_type = options[:invoice_type]
    @archived = options[:archived]
    @quote = options[:quote]
  end

  def records_total
    base_scope.count
  end

  def records_filtered
    filtered_scope.count
  end

  def data
    records = paginate(filtered_scope).to_a
    preload_associated_credit_notes(records)

    records.map do |invoice|
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

  def preload_associated_credit_notes(records)
    standard_invoices = records.select(&:standard?)
    return if standard_invoices.empty?

    standard_numbers = standard_invoices.map(&:invoice_number).compact.uniq
    return if standard_numbers.empty?

    existing_credit_notes = current_user.invoices
      .where(invoice_category: "credit_note", invoice_number: standard_numbers)
      .pluck(:invoice_number, :invoice_type, :sale_from_id)
      .map { |num, type, sf_id| "#{num}_#{type}_#{sf_id}" }
      .to_set

    standard_invoices.each do |inv|
      key = "#{inv.invoice_number}_#{inv.invoice_type}_#{inv.sale_from_id}"
      inv.instance_variable_set(:@has_associated_credit_note, existing_credit_notes.include?(key))
    end
  end

  def sortable_columns
    counterparty_col = if @invoice_type == 'purchase' || is_purchase_table?
      'COALESCE(sale_froms_invoices.name, companies.name)'
    else
      'COALESCE(companies.name, sale_froms_invoices.name)'
    end

    {
      0 => 'invoices.invoice_number',
      1 => counterparty_col,
      2 => "COALESCE(NULLIF(invoices.total->>'grand_total', ''), '0')::numeric",
      3 => 'invoices.issue_date',
      5 => 'invoices.status'
    }
  end

  def base_scope
    scope = current_user.invoices
      .includes(:recipient_company, :sale_from)
      .left_joins(:recipient_company, :sale_from)
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

    # Apply column-specific status filter if present
    status_filter = column_search_value('status') || column_search_value('5') || params[:status]
    if status_filter.present?
      clean_status = status_filter.to_s.gsub(/[\^\$]/, '').downcase
      scope = scope.where(status: clean_status) if clean_status.present?
    end

    # Apply search if provided
    if search_value.present?
      scope = apply_search(scope, SEARCHABLE_COLUMNS)
    end

    # Apply ordering - default to most recent first
    apply_order(scope, sortable_columns)
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
    return content_tag(:span, 'No File', class: 'text-muted') if invoice.recurring_sub_invoice?
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
        filename = file.filename.to_s
        if file.content_type.to_s.start_with?("image/")
          content_tag(:div, class: 'col-12 mb-3') do
            content_tag(:div, class: 'd-flex flex-column align-items-center justify-content-center bg-light border rounded p-2', style: 'min-height: 200px;') do
              img_link = link_to(file_url, target: "_blank", class: 'd-block text-center w-100 mb-2') do
                tag.img(src: file_url, class: 'img-fluid rounded shadow-sm', style: 'max-height: 70vh; object-fit: contain;', alt: 'Attachment', loading: 'lazy')
              end
              info_box = content_tag(:div, class: 'w-100 d-flex align-items-center justify-content-between pt-2 border-top gap-2', style: 'min-width: 0;') do
                name_span = content_tag(:span, filename, class: 'text-truncate small text-muted text-start flex-grow-1 me-2', style: 'min-width: 0;', title: filename)
                view_link = link_to('View Image', file_url, target: '_blank', class: 'btn btn-sm btn-outline-secondary flex-shrink-0')
                name_span + view_link
              end
              img_link + info_box
            end
          end
        elsif file.content_type.to_s == 'application/pdf'
          content_tag(:div, class: 'col-md-6 mb-3') do
            content_tag(:div, class: 'd-flex align-items-center justify-content-between border p-2 rounded gap-2', style: 'min-width: 0;') do
              name_span = content_tag(:span, filename, class: 'text-truncate small me-2 flex-grow-1', style: 'min-width: 0;', title: filename)
              view_link = link_to('View PDF', view.rails_blob_path(file, disposition: 'inline'), target: '_blank', class: 'btn btn-sm btn-outline-secondary flex-shrink-0')
              name_span + view_link
            end
          end
        else
          content_tag(:div, class: 'col-md-6 mb-3') do
            content_tag(:div, class: 'd-flex align-items-center justify-content-between border p-2 rounded gap-2', style: 'min-width: 0;') do
              name_span = content_tag(:span, filename, class: 'text-truncate small me-2 flex-grow-1', style: 'min-width: 0;', title: filename)
              view_link = link_to('Download', file_url, class: 'btn btn-sm btn-outline-secondary flex-shrink-0', target: '_blank')
              name_span + view_link
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
    dropdown = content_tag(:div, class: 'dropdown text-center') do
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

    modal = if is_purchase_table? && invoice.status == 'approved' && !invoice.has_associated_credit_note? && !invoice.quote?
      view.render(partial: 'invoices/partials/submit_tax_documents_modal', formats: [:html], locals: { invoice: invoice })
    else
      ''
    end

    dropdown + modal
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

    # Mark as Paid (only seller/issuer of sale invoice can mark as paid)
    if invoice.invoice_type == 'sale' && %w[approved sent].include?(invoice.status) && !is_purchase_table? && !is_received_quotes_table?
      items << content_tag(:li) do
        link_to('Mark as Paid',
          url_helpers.mark_as_paid_invoice_path(invoice, tab: active_tab),
          data: { turbo_method: :patch, turbo_confirm: 'Mark this invoice as paid?' },
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

    # Approve / Reject (purchase pending)
    if invoice.invoice_type == 'purchase' && invoice.status == 'pending' && !invoice.has_associated_credit_note?
      items << content_tag(:li) do
        link_to('Approve',
          url_helpers.approve_invoice_path(invoice, tab: active_tab),
          data: { turbo_method: :patch, turbo_confirm: 'Approve this purchase invoice?' },
          class: 'dropdown-item')
      end
      items << content_tag(:li) do
        link_to('Reject',
          url_helpers.reject_invoice_path(invoice, tab: active_tab),
          data: { turbo_method: :patch, turbo_confirm: 'Reject this purchase invoice?' },
          class: 'dropdown-item')
      end
    end

    # Submit Tax Documents (purchase approved, not quote)
    if is_purchase_table? && invoice.status == 'approved' && !invoice.has_associated_credit_note? && !invoice.quote?
      items << content_tag(:li) do
        link_to('Submit Tax Documents', '#',
          class: 'dropdown-item',
          data: { 'bs-toggle' => 'modal', 'bs-target' => "#submitTaxModal-#{invoice.id}" })
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
          data: { turbo_method: :patch, turbo_confirm: "#{action} this invoice?" },
          class: invoice.archived? ? 'dropdown-item' : 'dropdown-item')
      end
    end

    # Delete (draft only)
    if invoice.status == 'draft'
      items << content_tag(:li) do
        link_to('Delete',
          url_helpers.invoice_path(invoice, tab: active_tab),
          data: { turbo_method: :delete, turbo_confirm: 'Are you sure you want to delete this invoice?' },
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
