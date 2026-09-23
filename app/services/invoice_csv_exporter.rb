# frozen_string_literal: true

require 'csv'

# InvoiceCsvExporter
# Exports filtered invoice records to CSV formatted for bookkeeping and financial reporting.
# Compliant with RFC 4180 and protected against CSV Formula Injection (CWE-1236).
class InvoiceCsvExporter
  # Security (CWE-1236): Prevent CSV Formula Injection
  # Disallow execution of spreadsheets formulas starting with =, +, -, @, \t, \r
  FORMULA_PREFIX_REGEX = /\A[=+\-@\t\r]/

  attr_reader :invoices, :options

  def initialize(invoices, options = {})
    @invoices = invoices
    @options = options
    @invoice_type = options[:invoice_type]
    @tab = options[:tab]
  end

  def generate
    csv_data = CSV.generate(headers: true) do |csv|
      csv << headers.map { |h| sanitize_cell(h) }

      # Batch iterate to avoid high memory overhead for large collections
      relation = @invoices.includes(:recipient_company, :sale_from, :user)
      if relation.respond_to?(:find_each)
        relation.find_each(batch_size: 500) do |invoice|
          csv << row_for(invoice).map { |cell| sanitize_cell(cell) }
        end
      else
        relation.each do |invoice|
          csv << row_for(invoice).map { |cell| sanitize_cell(cell) }
        end
      end
    end

    # Prepend UTF-8 Byte Order Mark (\uFEFF) for Microsoft Excel compatibility
    "\uFEFF" + csv_data
  end

  def headers
    counterparty_label = if purchase_context?
      'Supplier Name'
    elsif sale_context?
      'Customer Name'
    else
      'Customer / Supplier Name'
    end

    counterparty_tin_label = if purchase_context?
      'Supplier TIN'
    elsif sale_context?
      'Customer TIN'
    else
      'Customer / Supplier TIN'
    end

    [
      'Invoice #',
      'Transaction Type',
      'Category',
      'Status',
      'Issue Date',
      'Due Date',
      counterparty_label,
      counterparty_tin_label,
      'Issuer / Seller Name',
      'Issuer TIN',
      'Currency',
      'Subtotal (Excl. Tax)',
      'Tax Amount',
      'Discount Amount',
      'Grand Total',
      'Payment Terms',
      'Attachments Count',
      'Notes',
      'Record State',
      'Created At'
    ]
  end

  def row_for(invoice)
    total_hash = invoice.total.is_a?(Hash) ? invoice.total : {}
    subtotal = total_hash['subtotal'].to_s.delete(',').to_f
    tax = total_hash['tax'].to_s.delete(',').to_f
    discount = total_hash['discount'].to_s.delete(',').to_f
    grand_total = invoice.grand_total

    [
      invoice.invoice_number.to_s,
      invoice.invoice_type.to_s.titleize,
      invoice.invoice_category.to_s.titleize,
      format_status(invoice),
      invoice.issue_date&.strftime('%Y-%m-%d') || '',
      extract_due_date(invoice),
      counterparty_name(invoice),
      counterparty_tin(invoice),
      issuer_name(invoice),
      issuer_tin(invoice),
      invoice.currency.presence || 'PHP',
      format('%.2f', subtotal),
      format('%.2f', tax),
      format('%.2f', discount),
      format('%.2f', grand_total),
      summarize_payment_terms(invoice),
      invoice.attachments.attached? ? invoice.attachments.count.to_s : '0',
      [invoice.recipient_note, invoice.message].compact_blank.join(' | '),
      invoice.archived? ? 'Archived' : 'Active',
      invoice.created_at&.strftime('%Y-%m-%d %H:%M:%S') || ''
    ]
  end

  def sanitize_cell(value)
    return '' if value.nil?

    str = value.to_s.strip
    # Guard against CSV Formula Injection (CWE-1236)
    if str =~ FORMULA_PREFIX_REGEX
      str = "'#{str}"
    end
    str
  end

  private

  def purchase_context?
    @invoice_type == 'purchase' || (@tab.present? && @tab.include?('purchase'))
  end

  def sale_context?
    @invoice_type == 'sale' || (@tab.present? && @tab.include?('sales'))
  end

  def counterparty_name(invoice)
    name = if invoice.invoice_type == 'purchase' || purchase_context?
      invoice.sale_from&.name || '—'
    else
      invoice.recipient_company&.name || '—'
    end
    name.presence || '—'
  end

  def counterparty_tin(invoice)
    tin = if invoice.invoice_type == 'purchase' || purchase_context?
      invoice.sale_from&.tax_id_number
    else
      invoice.recipient_company&.tax_id_number
    end
    tin.presence || '—'
  end

  def issuer_name(invoice)
    name = invoice.sale_from&.name || invoice.user&.company&.name
    name.presence || '—'
  end

  def issuer_tin(invoice)
    tin = invoice.sale_from&.tax_id_number || invoice.user&.company&.tax_id_number
    tin.presence || '—'
  end

  def format_status(invoice)
    if invoice.quote? && invoice.invoice_type == 'purchase' && invoice.status == 'sent'
      'Received'
    else
      invoice.status.to_s.capitalize
    end
  end

  def extract_due_date(invoice)
    return '' unless invoice.payment_terms.is_a?(Hash)

    invoice.payment_terms.each do |_group, fields|
      next unless fields.is_a?(Hash)

      fields.each do |k, v|
        if k.to_s.include?('due_date') && v.present?
          return v.to_s
        end
      end
    end
    ''
  end

  def summarize_payment_terms(invoice)
    return '' unless invoice.payment_terms.is_a?(Hash) && invoice.payment_terms.present?

    payment_labels = {
      'cash' => 'Cash Payment',
      'check' => 'Check Payment',
      'bank' => 'Bank Transfer',
      'bank_card' => 'Bank Card Payment'
    }

    terms = []
    invoice.payment_terms.each do |group_key, fields|
      next if fields.blank? && !payment_labels.key?(group_key)

      terms << (payment_labels[group_key] || group_key.to_s.titleize)
    end
    terms.join(', ')
  end
end
