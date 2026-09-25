/**
 * Invoices CSV Export Engine
 * Exports currently filtered DataTables records for bookkeeping and financial reporting.
 * Compliant with RFC 4180 and protected against CSV Formula Injection (CWE-1236).
 */

/**
 * Displays a non-blocking toast notification using safe DOM methods (no innerHTML).
 *
 * @param {string} message
 * @param {'success'|'warning'|'danger'|'info'} type
 */
export function showInvoiceToast(message, type = 'success') {
  const container = document.getElementById('live_notification_toasts');
  if (!container) return;

  const toastEl = document.createElement('div');
  let bgClass = 'text-bg-primary';
  let iconClass = 'fa-solid fa-circle-check fs-6';

  if (type === 'warning') {
    bgClass = 'text-bg-warning';
    iconClass = 'fa-solid fa-triangle-exclamation fs-6';
  } else if (type === 'danger') {
    bgClass = 'text-bg-danger';
    iconClass = 'fa-solid fa-circle-xmark fs-6';
  } else if (type === 'info') {
    bgClass = 'text-bg-info text-white';
    iconClass = 'fa-solid fa-circle-info fs-6';
  }

  toastEl.className = `toast live-notification-toast align-items-center ${bgClass} border-0 mb-2 shadow`;
  toastEl.setAttribute('role', 'alert');
  toastEl.setAttribute('aria-live', 'assertive');
  toastEl.setAttribute('aria-atomic', 'true');

  const flexDiv = document.createElement('div');
  flexDiv.className = 'd-flex align-items-center justify-content-between p-2';

  const bodyDiv = document.createElement('div');
  bodyDiv.className = 'toast-body d-flex align-items-center gap-2 py-1';

  const icon = document.createElement('i');
  icon.className = iconClass;
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
    const bsToast = bootstrap.Toast.getOrCreateInstance(toastEl, { delay: 4500, autohide: true });
    bsToast.show();
  }
}

/**
 * Triggers server-side CSV export for the given DataTable element or active table,
 * respecting current search query, status card filter, and active tab.
 *
 * @param {jQuery|HTMLElement} [tableElement]
 */
export function exportInvoicesToCsv(tableElement) {
  let $table = tableElement ? $(tableElement) : null;

  if (!$table || !$table.length) {
    // Find table in currently active tab and subtab
    const $activeTabPane = $('.invoices-page .tab-content > .tab-pane.active, .invoices-page .tab-content > .tab-pane.show.active');
    const $activeSubPane = $activeTabPane.find('.tab-content > .tab-pane.active, .tab-content > .tab-pane.show.active');
    const $targetPane = $activeSubPane.length ? $activeSubPane : $activeTabPane;
    $table = $targetPane.find('table.invoice-datatable');
  }

  if (!$table.length) {
    showInvoiceToast('No active invoice table found to export.', 'warning');
    return;
  }

  let tableApi = null;
  if (typeof $ !== 'undefined' && $.fn.DataTable && $.fn.DataTable.isDataTable($table[0])) {
    tableApi = $table.DataTable();
  }

  // Parse server-side ajax parameters
  let ajaxData = {};
  try {
    const rawData = $table.attr('data-ajax-data');
    if (rawData) {
      ajaxData = JSON.parse(rawData);
    }
  } catch (e) {
    console.warn('Failed to parse data-ajax-data:', e);
  }

  // Determine active search value
  const searchValue = tableApi ? (tableApi.search() || '') : '';

  // Determine active status filter
  let statusFilter = '';
  if (tableApi) {
    const colSearch = tableApi.column(6).search() || tableApi.column(5).search();
    if (colSearch) {
      statusFilter = colSearch.replace(/[\^\$]/g, '').trim();
    }
  }
  if (!statusFilter) {
    const $activeCard = $table.closest('.tab-pane').find('.card-filter.active');
    if ($activeCard.length) {
      statusFilter = ($activeCard.data('status') || '').toString().trim();
    }
  }

  // Determine sort order
  let orderColumn = 4;
  let orderDir = 'desc';
  if (tableApi) {
    const order = tableApi.order();
    if (order && order[0]) {
      orderColumn = order[0][0];
      orderDir = order[0][1];
    }
  }

  // Build query string
  const params = new URLSearchParams();
  if (ajaxData.invoice_type) params.set('invoice_type', ajaxData.invoice_type);
  if (ajaxData.archived !== undefined) params.set('archived', ajaxData.archived);
  if (ajaxData.quote !== undefined) params.set('quote', ajaxData.quote);
  if (ajaxData.tab) params.set('tab', ajaxData.tab);
  if (searchValue) params.set('search', searchValue);
  if (statusFilter) params.set('status', statusFilter);
  params.set('order_column', orderColumn);
  params.set('order_dir', orderDir);

  const exportUrl = `/invoices/export_csv?${params.toString()}`;

  showInvoiceToast('Preparing CSV export for bookkeeping & financial reporting...', 'info');

  fetch(exportUrl, {
    method: 'GET',
    headers: {
      'Accept': 'text/csv'
    }
  })
    .then(async (response) => {
      if (!response.ok) {
        throw new Error(`Export request failed with status: ${response.status}`);
      }

      const count = response.headers.get('X-Total-Count');
      if (count === '0') {
        showInvoiceToast('No records match the current filter to export.', 'warning');
        return;
      }

      // Extract filename from Content-Disposition if present
      const disposition = response.headers.get('Content-Disposition');
      let filename = 'invoices_export.csv';
      if (disposition && disposition.indexOf('filename=') !== -1) {
        const matches = /filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/.exec(disposition);
        if (matches != null && matches[1]) {
          filename = matches[1].replace(/['"]/g, '');
        }
      }

      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = filename;
      link.style.display = 'none';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);

      const countText = count ? `${count} ` : '';
      showInvoiceToast(`Exported ${countText}filtered invoice record${count === '1' ? '' : 's'} to ${filename}.`, 'success');
    })
    .catch((err) => {
      console.error('Invoice CSV export error:', err);
      showInvoiceToast('Failed to export invoices. Please try again.', 'danger');
    });
}

/**
 * Initializes event listeners for CSV Export buttons on the Invoices page.
 */
export function initInvoiceExport() {
  // Global Header Export CSV Button
  $(document).off('click.exportInvoices', '#exportInvoicesBtn').on('click.exportInvoices', '#exportInvoicesBtn', function (e) {
    e.preventDefault();
    exportInvoicesToCsv();
  });

  // Card Header Sub-Tab Export CSV Buttons
  $(document).off('click.exportInvoicesSub', '.export-invoices-sub-btn').on('click.exportInvoicesSub', '.export-invoices-sub-btn', function (e) {
    e.preventDefault();
    const $card = $(this).closest('.card');
    const $activePane = $card.find('.tab-content > .tab-pane.active, .tab-content > .tab-pane.show.active');
    const $table = $activePane.find('table.invoice-datatable');
    exportInvoicesToCsv($table);
  });
}
