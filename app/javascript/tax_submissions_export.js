/**
 * Tax Submissions CSV Export Engine
 * Exports currently filtered DataTables records for bookkeeping and financial reporting.
 * Compliant with RFC 4180 and protected against CSV Formula Injection (CWE-1236).
 */

/**
 * Escapes a cell value for CSV output, guarding against CSV Formula Injection (CWE-1236).
 * Prepends a single quote if the value begins with formula characters (=, +, -, @, \t, \r).
 *
 * @param {*} value
 * @returns {string} Safe quoted CSV cell
 */
export function sanitizeCsvCell(value) {
  if (value === null || value === undefined) {
    return '""';
  }
  let str = String(value).trim();

  // Guard against CSV Formula Injection (CWE-1236)
  if (/^[=+\-@\t\r]/.test(str)) {
    str = "'" + str;
  }

  // Escape internal double quotes per RFC 4180
  str = str.replace(/"/g, '""');

  return `"${str}"`;
}

/**
 * Displays a non-blocking toast notification to the user without using unsafe innerHTML.
 *
 * @param {string} message
 * @param {'success'|'warning'|'danger'|'info'} type
 */
export function showTaxToast(message, type = 'success') {
  const container = document.getElementById('live_notification_toasts');
  if (!container) return;

  const toastEl = document.createElement('div');
  const bgClass = type === 'warning' ? 'text-bg-warning' : (type === 'danger' ? 'text-bg-danger' : 'text-bg-primary');
  toastEl.className = `toast live-notification-toast align-items-center ${bgClass} border-0 mb-2 shadow`;
  toastEl.setAttribute('role', 'alert');
  toastEl.setAttribute('aria-live', 'assertive');
  toastEl.setAttribute('aria-atomic', 'true');

  const flexDiv = document.createElement('div');
  flexDiv.className = 'd-flex align-items-center justify-content-between p-2';

  const bodyDiv = document.createElement('div');
  bodyDiv.className = 'toast-body d-flex align-items-center gap-2 py-1';

  const icon = document.createElement('i');
  icon.className = type === 'warning' ? 'fa-solid fa-triangle-exclamation fs-6' : 'fa-solid fa-circle-check fs-6';
  bodyDiv.appendChild(icon);

  const span = document.createElement('span');
  span.textContent = message;
  bodyDiv.appendChild(span);

  const closeBtn = document.createElement('button');
  closeBtn.type = 'button';
  closeBtn.className = 'btn-close btn-close-white me-2 m-auto';
  closeBtn.setAttribute('data-bs-dismiss', 'toast');
  closeBtn.setAttribute('aria-label', 'Close');

  flexDiv.appendChild(bodyDiv);
  flexDiv.appendChild(closeBtn);
  toastEl.appendChild(flexDiv);

  container.appendChild(toastEl);

  if (typeof bootstrap !== 'undefined' && bootstrap.Toast) {
    const bsToast = new bootstrap.Toast(toastEl, { delay: 4500, autohide: true });
    bsToast.show();
  }
}

/**
 * Exports all rows matching current DataTables filters (across all pages) to CSV.
 *
 * @param {object} tableApi - DataTables API instance
 * @param {string} filePrefix - Filename prefix (e.g. tax_submissions_active)
 * @param {boolean} isIncoming - Whether the table represents incoming submissions (includes Email column)
 */
export function exportSubmissionsToCsv(tableApi, filePrefix = 'tax_submissions', isIncoming = false) {
  if (!tableApi) return;

  // Retrieve DOM nodes for all rows matching currently applied filters
  const rows = tableApi.rows({ search: 'applied' }).nodes();
  const rowCount = rows ? rows.length : 0;

  if (rowCount === 0) {
    showTaxToast('No records match the current filter to export.', 'warning');
    return;
  }

  const headers = [
    'Transaction ID',
    'Submission Date',
    isIncoming ? 'Sender Email' : null,
    'Company / Withholding Agent',
    'Company TIN',
    'Invoice Number',
    'Invoice Issue Date',
    'Currency',
    'Taxable Base / Subtotal',
    'Tax Withheld (Form 2307)',
    'Invoice Grand Total',
    'Invoice Status',
    'Compliance Status',
    'Form 2307 Attached',
    'Form 2307 Filename',
    'Deposit Slip Attached',
    'Deposit Slip Count',
    'Deposit Slip Filenames',
    'Notes / Details',
    'Record State'
  ].filter(Boolean);

  const csvLines = [];
  csvLines.push(headers.map(h => sanitizeCsvCell(h)).join(','));

  for (let i = 0; i < rowCount; i++) {
    const tr = rows[i];
    const $tr = $(tr);

    const transactionId = $tr.attr('data-transaction-id') || $tr.find('td:eq(0)').text().trim();
    const dateSubmitted = $tr.attr('data-date-submitted') || '';
    const email = isIncoming ? ($tr.attr('data-email') || $tr.find('td:eq(1)').text().trim()) : null;
    const companyName = $tr.attr('data-company-name') || '';
    const companyTin = $tr.attr('data-company-tin') || '';
    const invoiceNumber = $tr.attr('data-invoice-number') || '';
    const invoiceDate = $tr.attr('data-invoice-date') || '';
    const currency = $tr.attr('data-currency') || 'PHP';
    const subtotal = $tr.attr('data-subtotal') || '';
    const taxAmount = $tr.attr('data-tax-amount') || '';
    const grandTotal = $tr.attr('data-grand-total') || '';
    const invoiceStatus = $tr.attr('data-invoice-status') || '';
    const status = $tr.attr('data-status') || '';
    const form2307Attached = $tr.attr('data-form-2307-attached') || ($tr.find('button[data-bs-target*="form2307"]').length ? 'Yes' : 'No');
    const form2307Filename = $tr.attr('data-form-2307-filename') || '';
    const depositSlipAttached = $tr.attr('data-deposit-slip-attached') || ($tr.find('button[data-bs-target*="depositModal"]').length ? 'Yes' : 'No');
    const depositSlipCount = $tr.attr('data-deposit-slip-count') || '';
    const depositSlipFilenames = $tr.attr('data-deposit-slip-filenames') || '';
    const details = $tr.attr('data-details') || '';
    const archived = $tr.attr('data-archived') || '';

    const rowValues = [
      transactionId,
      dateSubmitted,
      isIncoming ? email : null,
      companyName,
      companyTin,
      invoiceNumber,
      invoiceDate,
      currency,
      subtotal,
      taxAmount,
      grandTotal,
      invoiceStatus,
      status,
      form2307Attached,
      form2307Filename,
      depositSlipAttached,
      depositSlipCount,
      depositSlipFilenames,
      details,
      archived
    ].filter(v => v !== null);

    csvLines.push(rowValues.map(v => sanitizeCsvCell(v)).join(','));
  }

  // Prepend UTF-8 Byte Order Mark (\uFEFF) for Microsoft Excel compatibility
  const csvContent = '\uFEFF' + csvLines.join('\r\n');
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });

  // Generate ISO date stamp for filename: YYYY-MM-DD
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  const hours = String(now.getHours()).padStart(2, '0');
  const mins = String(now.getMinutes()).padStart(2, '0');
  const filename = `${filePrefix}_${year}-${month}-${day}_${hours}${mins}.csv`;

  // Trigger file download
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  link.setAttribute('href', url);
  link.setAttribute('download', filename);
  link.style.display = 'none';
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);

  showTaxToast(`Exported ${rowCount} filtered submission record${rowCount === 1 ? '' : 's'} to ${filename}.`, 'success');
}
