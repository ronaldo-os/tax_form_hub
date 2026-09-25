/**
 * Invoices Bulk Actions Manager
 * Handles multi-row checkbox selection, state synchronization across pages,
 * bulk status updates, bulk archiving/deletion, and client-side ZIP of PDFs export.
 * Strict compliance with Secure Coding Guidelines (strict DOM API, no innerHTML).
 */

import JSZip from 'jszip';
import { showInvoiceToast } from './invoices_export';

/**
 * Global map storing selected invoices per table ID:
 * tableId -> Map(invoiceId -> { id, number, status, type })
 */
const tableSelections = new Map();

/**
 * Loads html2pdf.js dynamically from CDN if not already present.
 */
function loadHtml2Pdf() {
  if (typeof html2pdf !== 'undefined') {
    return Promise.resolve();
  }
  return new Promise((resolve, reject) => {
    const existing = document.querySelector('script[src*="html2pdf"]');
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('Failed to load html2pdf library')));
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js';
    script.crossOrigin = 'anonymous';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Failed to load html2pdf library'));
    document.head.appendChild(script);
  });
}

/**
 * Renders an invoice's HTML partial into a PDF Blob off-screen.
 *
 * @param {string|number} invoiceId
 * @returns {Promise<Blob>}
 */
function renderInvoiceToPdfBlob(invoiceId) {
  return new Promise((resolve, reject) => {
    $.ajax({
      url: `/invoices/${invoiceId}/pdf_partial`,
      method: 'GET',
      success: function (html) {
        const temp = document.createElement('div');
        temp.classList.add('force-light-mode', 'invoice-card');
        temp.setAttribute('data-theme', 'light');
        temp.setAttribute('data-bs-theme', 'light');
        temp.innerHTML = html;
        temp.style.position = 'absolute';
        temp.style.left = '-9999px';
        temp.style.top = '0';
        temp.style.width = '1000px';
        temp.style.background = 'white';
        temp.style.color = 'black';
        temp.style.opacity = '0';
        temp.style.pointerEvents = 'none';
        document.body.appendChild(temp);

        let invoice = temp.querySelector('#invoice_card');
        if (!invoice) {
          if (document.body.contains(temp)) document.body.removeChild(temp);
          return reject(new Error(`Invoice card for ID ${invoiceId} not found in partial.`));
        }

        // Clean container
        const content = document.createElement('div');
        content.classList.add('invoice-card');
        while (invoice.firstChild) {
          content.appendChild(invoice.firstChild);
        }
        invoice.parentNode.replaceChild(content, invoice);
        invoice = content;

        // Prevent awkward breaks
        const noBreakElements = invoice.querySelectorAll(
          'table tr, .card, .pdf-no-break, .payment-terms-box, .message-box, .totals-section, .attachment-card, .line-item, .price-adjustment-row'
        );
        noBreakElements.forEach((el) => {
          el.style.pageBreakInside = 'avoid';
          el.style.breakInside = 'avoid';
        });

        const tables = invoice.querySelectorAll('table');
        tables.forEach((table) => {
          table.style.pageBreakInside = 'auto';
        });

        // Strip borders/backgrounds for attachments
        const attachmentContainers = invoice.querySelectorAll(
          '#attachments-section, #modal_new_attachments_preview, #persisted-attachments-container'
        );
        attachmentContainers.forEach((container) => {
          container.querySelectorAll('.card').forEach((card) => {
            card.style.border = '1px solid white';
            card.style.boxShadow = 'none';
          });
          container.querySelectorAll('.bg-light').forEach((el) => {
            el.classList.remove('bg-light');
            el.style.backgroundColor = 'transparent';
          });
        });

        // Strip interactive buttons & embeds
        invoice.querySelectorAll('a.btn.btn-outline-primary, a.btn.btn-sm.btn-outline-primary').forEach((btn) => {
          if (btn.textContent.trim() === 'Download') btn.remove();
        });
        invoice.querySelectorAll('embed, object, iframe').forEach((el) => el.remove());

        // Slight scaling to prevent canvas truncation
        invoice.style.transform = 'scale(0.99)';
        invoice.style.transformOrigin = 'top left';

        const images = Array.from(invoice.querySelectorAll('img'));
        const imagePromises = images.map((img) => {
          if (img.complete) return Promise.resolve();
          return new Promise((r) => {
            img.onload = img.onerror = r;
          });
        });

        Promise.all([...imagePromises, loadHtml2Pdf()])
          .then(() => {
            const opt = {
              margin: [9, 9, 9, 9],
              image: { type: 'jpeg', quality: 0.98 },
              html2canvas: {
                scale: 1.5,
                useCORS: true,
                letterRendering: true,
                logging: false
              },
              jsPDF: {
                unit: 'pt',
                format: 'a4',
                orientation: 'portrait',
                compress: true
              },
              pagebreak: {
                mode: ['css', 'legacy'],
                after: '.page-break-after',
                avoid: [
                  'tr',
                  '.card',
                  'table',
                  '.no-break',
                  '.pdf-no-break',
                  '.payment-terms-box',
                  '.message-box',
                  '.totals-section',
                  '.attachment-card',
                  '.line-item',
                  '.price-adjustment-row'
                ]
              }
            };

            html2pdf()
              .set(opt)
              .from(invoice)
              .toPdf()
              .get('pdf')
              .then(function (pdf) {
                const blob = pdf.output('blob');
                if (document.body.contains(temp)) document.body.removeChild(temp);
                resolve(blob);
              })
              .catch(function (err) {
                if (document.body.contains(temp)) document.body.removeChild(temp);
                reject(err);
              });
          })
          .catch((err) => {
            if (document.body.contains(temp)) document.body.removeChild(temp);
            reject(err);
          });
      },
      error: function (xhr, status, err) {
        reject(new Error(`Server error loading invoice #${invoiceId}: ${err}`));
      }
    });
  });
}

/**
 * Creates or gets the progress overlay modal for ZIP export.
 */
function getOrCreateZipProgressOverlay() {
  let overlay = document.getElementById('zip-export-overlay');
  if (overlay) return overlay;

  overlay = document.createElement('div');
  overlay.id = 'zip-export-overlay';
  overlay.style.position = 'fixed';
  overlay.style.top = '0';
  overlay.style.left = '0';
  overlay.style.width = '100vw';
  overlay.style.height = '100vh';
  overlay.style.zIndex = '999999';
  overlay.style.display = 'flex';
  overlay.style.flexDirection = 'column';
  overlay.style.justifyContent = 'center';
  overlay.style.alignItems = 'center';
  overlay.style.backgroundColor = 'rgba(0, 0, 0, 0.65)';
  overlay.style.padding = '1.5rem';

  const card = document.createElement('div');
  card.className = 'card border-0 shadow-lg p-4 text-center rounded-4 zip-progress-card';
  card.style.maxWidth = '460px';
  card.style.width = '100%';

  const spinner = document.createElement('div');
  spinner.className = 'spinner-border text-primary mx-auto mb-3';
  spinner.style.width = '3.5rem';
  spinner.style.height = '3.5rem';
  spinner.setAttribute('role', 'status');

  const title = document.createElement('h5');
  title.className = 'fw-bold mb-2 zip-overlay-title';
  title.textContent = 'Exporting Invoices as ZIP...';

  const statusMsg = document.createElement('p');
  statusMsg.className = 'text-muted small mb-3 zip-overlay-status';
  statusMsg.textContent = 'Initializing PDF generator...';

  const progressWrap = document.createElement('div');
  progressWrap.className = 'progress mb-2';
  progressWrap.style.height = '8px';

  const progressBar = document.createElement('div');
  progressBar.className = 'progress-bar progress-bar-striped progress-bar-animated bg-primary zip-overlay-bar';
  progressBar.style.width = '0%';
  progressBar.setAttribute('role', 'progressbar');
  progressBar.setAttribute('aria-valuenow', '0');
  progressBar.setAttribute('aria-valuemin', '0');
  progressBar.setAttribute('aria-valuemax', '100');
  progressWrap.appendChild(progressBar);

  const subtext = document.createElement('small');
  subtext.className = 'text-muted opacity-75';
  subtext.textContent = 'Please keep this tab open while generating PDFs and bundling archive.';

  card.appendChild(spinner);
  card.appendChild(title);
  card.appendChild(statusMsg);
  card.appendChild(progressWrap);
  card.appendChild(subtext);

  overlay.appendChild(card);
  document.body.appendChild(overlay);

  return overlay;
}

/**
 * Updates the ZIP progress overlay status and progress percentage.
 */
function updateZipProgress(percent, statusText) {
  const overlay = getOrCreateZipProgressOverlay();
  const bar = overlay.querySelector('.zip-overlay-bar');
  const status = overlay.querySelector('.zip-overlay-status');

  if (bar) {
    const clamped = Math.min(100, Math.max(0, percent));
    bar.style.width = `${clamped}%`;
    bar.setAttribute('aria-valuenow', clamped.toString());
  }

  if (status && statusText) {
    status.textContent = statusText;
  }
}

/**
 * Hides and removes the ZIP progress overlay.
 */
function hideZipProgress() {
  const overlay = document.getElementById('zip-export-overlay');
  if (overlay && overlay.parentNode) {
    overlay.parentNode.removeChild(overlay);
  }
}

/**
 * Exports selected invoices for a table as a ZIP containing individual PDF files.
 *
 * @param {string} tableId
 */
export async function exportSelectedInvoicesToZip(tableId) {
  const selectionMap = tableSelections.get(tableId);
  if (!selectionMap || selectionMap.size === 0) {
    showInvoiceToast('Please select at least one invoice to export.', 'warning');
    return;
  }

  const selectedInvoices = Array.from(selectionMap.values());
  const total = selectedInvoices.length;

  getOrCreateZipProgressOverlay();
  updateZipProgress(5, `Preparing to generate ${total} ${total === 1 ? 'invoice' : 'invoices'}...`);

  const zip = new JSZip();
  const usedFilenames = new Set();
  const today = new Date();
  const dateStr = today.toISOString().slice(0, 10);
  const timestamp = `${dateStr}_${String(today.getHours()).padStart(2, '0')}${String(today.getMinutes()).padStart(2, '0')}`;

  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < total; i++) {
    const item = selectedInvoices[i];
    const itemIndex = i + 1;
    const itemNumber = item.number || `Invoice_${item.id}`;
    const cleanNumber = itemNumber.toString().replace(/[^a-zA-Z0-9_\-]/g, '_');

    let filename = `${dateStr}-invoice-${cleanNumber}.pdf`;
    if (usedFilenames.has(filename)) {
      filename = `${dateStr}-invoice-${cleanNumber}_${item.id}.pdf`;
    }
    usedFilenames.add(filename);

    const progressPct = Math.round(5 + ((i / total) * 80));
    updateZipProgress(
      progressPct,
      `Generating PDF ${itemIndex} of ${total}: ${itemNumber}...`
    );

    try {
      const blob = await renderInvoiceToPdfBlob(item.id);
      zip.file(filename, blob);
      successCount++;
    } catch (err) {
      console.error(`Failed to generate PDF for invoice #${item.id}:`, err);
      failCount++;
      zip.file(
        `ERROR_${cleanNumber}.txt`,
        `Failed to generate PDF for invoice ${itemNumber} (ID: ${item.id}). Error: ${err.message}`
      );
    }
  }

  if (successCount === 0) {
    hideZipProgress();
    showInvoiceToast('Failed to generate any invoice PDFs. Please try again.', 'danger');
    return;
  }

  updateZipProgress(90, 'Compressing PDFs into ZIP archive...');

  try {
    const zipBlob = await zip.generateAsync(
      { type: 'blob', compression: 'DEFLATE', compressionOptions: { level: 6 } },
      (metadata) => {
        const zipPct = Math.round(90 + (metadata.percent * 0.09));
        updateZipProgress(zipPct, `Compressing: ${Math.round(metadata.percent)}%...`);
      }
    );

    updateZipProgress(100, 'Download starting...');

    const zipFilename = `invoices_export_${timestamp}.zip`;
    const downloadUrl = window.URL.createObjectURL(zipBlob);
    const downloadLink = document.createElement('a');
    downloadLink.href = downloadUrl;
    downloadLink.download = zipFilename;
    downloadLink.style.display = 'none';
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
    window.URL.revokeObjectURL(downloadUrl);

    setTimeout(() => {
      hideZipProgress();
      if (failCount > 0) {
        showInvoiceToast(
          `Exported ${successCount} invoice PDFs to ${zipFilename}. (${failCount} failed to render).`,
          'warning'
        );
      } else {
        showInvoiceToast(
          `Successfully exported ${successCount} invoice PDFs to ${zipFilename}.`,
          'success'
        );
      }
    }, 400);
  } catch (zipErr) {
    console.error('Error generating ZIP archive:', zipErr);
    hideZipProgress();
    showInvoiceToast('Failed to create ZIP file. Please try again.', 'danger');
  }
}

/**
 * Sets up Bulk Actions (selection, toolbar, form submission, and ZIP export) for an Invoice DataTable.
 *
 * @param {Object} tableApi - DataTables API instance
 * @param {string} tableId - HTML ID of the table element
 */
export function setupInvoiceBulkActions(tableApi, tableId) {
  if (!tableApi) return;

  const $table = $(tableApi.table().node());
  const effectiveTableId = tableId || $table.attr('id');
  if (!effectiveTableId) return;

  // Initialize selection set for this table if not present
  if (!tableSelections.has(effectiveTableId)) {
    tableSelections.set(effectiveTableId, new Map());
  }
  const selectionMap = tableSelections.get(effectiveTableId);

  const bulkBar = document.getElementById(`bulk_action_bar_${effectiveTableId}`);
  const bulkForm = document.getElementById(`bulk_form_${effectiveTableId}`);
  const headerCheckbox = document.getElementById(`header_checkbox_${effectiveTableId}`);
  const masterBulkCheckbox = document.getElementById(`master_bulk_${effectiveTableId}`);

  if (!bulkBar || !bulkForm) return;

  function updateBulkBar() {
    const count = selectionMap.size;

    // Safely update selected count text using textContent
    const countSpan = bulkBar.querySelector('.selected-count');
    if (countSpan) {
      countSpan.textContent = count.toString();
    }

    // Toggle bulk bar visibility
    if (count > 0) {
      bulkBar.classList.remove('d-none');
    } else {
      bulkBar.classList.add('d-none');
    }

    // Synchronize checkboxes in current DOM page with selectionMap
    const allRowNodes = tableApi.rows().nodes();
    let visibleTotal = 0;
    let visibleSelected = 0;

    $(allRowNodes).each(function () {
      const $cb = $(this).find('.invoice-row-checkbox');
      if ($cb.length) {
        visibleTotal++;
        const invId = $cb.val();
        const isSelected = selectionMap.has(invId);
        $cb.prop('checked', isSelected);
        $(this).toggleClass('row-selected table-active', isSelected);
        if (isSelected) visibleSelected++;
      }
    });

    // Synchronize header checkbox and master bulk bar checkbox
    const isAllVisibleSelected = visibleTotal > 0 && visibleSelected === visibleTotal;
    const isIndeterminate = visibleSelected > 0 && visibleSelected < visibleTotal;

    if (headerCheckbox) {
      headerCheckbox.checked = isAllVisibleSelected;
      headerCheckbox.indeterminate = isIndeterminate;
    }

    if (masterBulkCheckbox) {
      masterBulkCheckbox.checked = isAllVisibleSelected;
      masterBulkCheckbox.indeterminate = isIndeterminate;
    }
  }

  function toggleAllVisible(isChecked) {
    const activeRows = tableApi.rows({ search: 'applied' }).nodes();
    $(activeRows).each(function () {
      const $cb = $(this).find('.invoice-row-checkbox');
      if ($cb.length) {
        const invId = $cb.val();
        if (isChecked) {
          selectionMap.set(invId, {
            id: invId,
            number: $cb.data('invoice-number') || '',
            status: $cb.data('status') || '',
            type: $cb.data('invoice-type') || ''
          });
        } else {
          selectionMap.delete(invId);
        }
      }
    });
    updateBulkBar();
  }

  function clearAllSelections() {
    selectionMap.clear();
    updateBulkBar();
  }

  // Header checkbox toggle
  if (headerCheckbox && !headerCheckbox.dataset.bulkBound) {
    headerCheckbox.dataset.bulkBound = 'true';
    headerCheckbox.addEventListener('change', function () {
      toggleAllVisible(this.checked);
    });
  }

  // Master checkbox in bulk bar toggle
  if (masterBulkCheckbox && !masterBulkCheckbox.dataset.bulkBound) {
    masterBulkCheckbox.dataset.bulkBound = 'true';
    masterBulkCheckbox.addEventListener('change', function () {
      toggleAllVisible(this.checked);
    });
  }

  // Row checkbox change (delegated to table node for dynamic / paginated rows)
  $table.off('change.invoiceCheckbox', '.invoice-row-checkbox').on('change.invoiceCheckbox', '.invoice-row-checkbox', function () {
    const invId = this.value;
    if (this.checked) {
      selectionMap.set(invId, {
        id: invId,
        number: this.dataset.invoiceNumber || $(this).data('invoice-number') || '',
        status: this.dataset.status || $(this).data('status') || '',
        type: this.dataset.invoiceType || $(this).data('invoice-type') || ''
      });
    } else {
      selectionMap.delete(invId);
    }
    updateBulkBar();
  });

  // Clear selection button
  const clearBtn = bulkBar.querySelector('.clear-selection-btn');
  if (clearBtn && !clearBtn.dataset.bulkBound) {
    clearBtn.dataset.bulkBound = 'true';
    clearBtn.addEventListener('click', function (e) {
      e.preventDefault();
      clearAllSelections();
    });
  }

  // Export ZIP button
  const zipBtn = bulkBar.querySelector('.bulk-export-zip-btn');
  if (zipBtn && !zipBtn.dataset.bulkBound) {
    zipBtn.dataset.bulkBound = 'true';
    zipBtn.addEventListener('click', function (e) {
      e.preventDefault();
      exportSelectedInvoicesToZip(effectiveTableId);
    });
  }

  // Form submission: inject hidden inputs for all selected invoices across all pages
  if (bulkForm && !bulkForm.dataset.bulkFormBound) {
    bulkForm.dataset.bulkFormBound = 'true';
    bulkForm.addEventListener('submit', function (e) {
      // Remove previously appended hidden inputs
      bulkForm.querySelectorAll('input[name="invoice_ids[]"]').forEach((el) => el.remove());

      if (selectionMap.size === 0) {
        e.preventDefault();
        showInvoiceToast('Please select at least one invoice.', 'warning');
        return;
      }

      selectionMap.forEach((_, invId) => {
        const hiddenInput = document.createElement('input');
        hiddenInput.setAttribute('type', 'hidden');
        hiddenInput.setAttribute('name', 'invoice_ids[]');
        hiddenInput.setAttribute('value', invId.toString());
        bulkForm.appendChild(hiddenInput);
      });
    });
  }

  // When DataTable is redrawn (page change, search, sort), re-apply selection states
  tableApi.off('draw.invoiceBulk').on('draw.invoiceBulk', function () {
    updateBulkBar();
  });

  // Initial synchronization
  updateBulkBar();
}
