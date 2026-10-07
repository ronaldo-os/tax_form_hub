import { updatePdfPreviewScale } from './invoice_preview';
import { initInvoiceExport, showInvoiceToast } from './invoices_export';
import { setupInvoiceBulkActions } from './invoice_bulk';
import { 
    getInitialTableState, 
    updateUrlParams, 
    bindSearchInputSync, 
    bindPaginationSync, 
    resolveSortOrder, 
    bindOrderSync, 
    getUrlParam 
} from './table_url_sync';

function loadHtml2Pdf() {
    if (typeof html2pdf !== 'undefined') {
        return Promise.resolve();
    }
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js';
        script.crossOrigin = 'anonymous';
        script.onload = () => resolve();
        script.onerror = () => reject(new Error('Failed to load html2pdf library'));
        document.head.appendChild(script);
    });
}

/**
 * Synchronizes the active visual state on .card-filter elements across all panes.
 * Ensures that if status is e.g. "paid", the Paid card is active, and if empty/null,
 * the Total card is active.
 */
function syncCardFilterState(targetStatus) {
    const statusVal = (targetStatus || '').toString().trim().toLowerCase();
    $('.invoice-stats-row').each(function () {
        const $row = $(this);
        $row.find('.card-filter').removeClass('active');
        if (statusVal && ['draft', 'sent', 'paid'].includes(statusVal)) {
            const $targetCard = $row.find(`.card-filter[data-status="${statusVal}"]`);
            if ($targetCard.length) {
                $targetCard.addClass('active');
            } else {
                $row.find('.card-filter[data-status=""], .card-filter:not([data-status])').first().addClass('active');
            }
        } else {
            $row.find('.card-filter[data-status=""], .card-filter:not([data-status])').first().addClass('active');
        }
    });
}

function initInvoicePage() {
    if (!window.location.pathname.includes("/invoices")) return;

    const initial = getInitialTableState();

    // Restore active tab if specified in URL and not already active
    const targetTab = initial.tab || 'sales-invoices';
    const mainTabBtn = document.getElementById(`${targetTab}-tab`);
    if (mainTabBtn && !mainTabBtn.classList.contains('active') && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
        bootstrap.Tab.getOrCreateInstance(mainTabBtn).show();
    }

    // Restore subtab (Active vs Archived) in the active tab
    const $targetMainPane = $(`#${targetTab}`);
    if ($targetMainPane.length && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
        const isArchived = initial.subtab === 'archived';
        const subTabSelector = isArchived ? '.invoice-sub-tabs button[id$="-archived-tab"]' : '.invoice-sub-tabs button[id$="-active-tab"]';
        const subTabBtn = $targetMainPane.find(subTabSelector)[0];
        if (subTabBtn && !subTabBtn.classList.contains('active')) {
            bootstrap.Tab.getOrCreateInstance(subTabBtn).show();
        }
    }

    // Synchronize status card selection across tabs
    syncCardFilterState(initial.status);

    initInvoiceExport();

    // Render mini charts for invoice trends
    function renderMiniCharts(prefix, trends, color) {

        $.each(trends, function (status, data) {
            const $canvas = $(`#${prefix}-${status}`);
            if (!$canvas.length) return;

            // Destroy existing chart if it exists attached to this canvas
            // This is a safety measure for Turbo re-renders if the canvas is preserved
            const existingChart = Chart.getChart($canvas[0]);
            if (existingChart) existingChart.destroy();

            const $wrapper = $canvas.closest('.chart-wrapper');
            // Filter out months with zero data to satisfy "not for empty months"
            const filteredData = data.filter(d => d.count > 0);

            if (filteredData.length === 0) {
                $wrapper.hide();
                return;
            }
            $wrapper.show();

            const ctx = $canvas[0].getContext("2d");

            new Chart(ctx, {
                type: "bar",
                data: {
                    labels: filteredData.map(d => d.month),
                    datasets: [{
                        data: filteredData.map(d => d.count),
                        backgroundColor: color,
                        borderRadius: 3,
                        barThickness: filteredData.length > 3 ? 3 : 6, // Thicker bars if fewer months to avoid looking like a 'dash'
                        borderWidth: 0,
                    }]
                },
                options: {
                    plugins: { legend: { display: false }, tooltip: { enabled: false } },
                    scales: {
                        x: {
                            display: false,
                            grid: { display: false },
                            border: { display: false }
                        },
                        y: {
                            display: false,
                            grid: { display: false },
                            border: { display: false }
                        }
                    },
                    elements: {
                        bar: {
                            borderSkipped: false,
                        }
                    },
                    layout: {
                        padding: 0
                    },
                    animation: false,
                    responsive: true,
                    maintainAspectRatio: false,
                }
            });
        });
    }

    // Get trends data from data attributes
    const $tabsContent = $('#invoiceTabsContent');
    const saleTrendsData = $tabsContent.data('sale-trends');
    const purchaseTrendsData = $tabsContent.data('purchase-trends');

    if (saleTrendsData && purchaseTrendsData) {
        renderMiniCharts("chart-sale", saleTrendsData, "#00aeff");
        renderMiniCharts("chart-purchase", purchaseTrendsData, "#00aeff");
    }

    // Initialize DataTables - Lazy load per tab for instant initial rendering
    function initSingleDataTable($table) {
        if (!$table.length || $.fn.DataTable.isDataTable($table[0])) return;

        const isServerSide = $table.attr('data-server-side') === 'true';
        const ajaxUrl = $table.data('ajax-url');
        let ajaxData = {};
        try {
            const ajaxDataAttr = $table.attr('data-ajax-data');
            if (ajaxDataAttr) {
                ajaxData = JSON.parse(ajaxDataAttr);
            }
        } catch (e) {
            console.warn('Failed to parse data-ajax-data:', e);
        }

        const currentTableState = getInitialTableState();
        const defaultOrder = [[4, 'desc']]; // Default order by Issue Date DESC (column 4 with checkbox at 0)
        const resolvedOrder = resolveSortOrder($table, currentTableState.sort, currentTableState.dir, defaultOrder);

        const tableConfig = {
            responsive: true,
            autoWidth: false,
            destroy: true, // Important for Turbo
            pageLength: 25,
            displayStart: currentTableState.page > 1 ? (currentTableState.page - 1) * 25 : 0,
            lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
            order: resolvedOrder,
            columnDefs: [
                { orderable: false, targets: [0, 5, 7, 8] }, // Disable sorting on Checkbox, Attachments, History, and Actions
                { className: 'text-center', targets: [0, 7, 8] },
                {
                    targets: 6, // Status column
                    render: function (data, type, row) {
                        if (type === 'display' && data) {
                            const statusLower = data.toString().toLowerCase().trim();
                            let pillClass = 'status-pill-secondary';
                            if (statusLower === 'paid' || statusLower === 'approved') pillClass = 'status-pill-success';
                            else if (statusLower === 'sent' || statusLower === 'received') pillClass = 'status-pill-info';
                            else if (statusLower === 'draft') pillClass = 'status-pill-secondary';
                            else if (['rejected', 'cancelled', 'overdue'].includes(statusLower)) pillClass = 'status-pill-danger';
                            return `<span class="status-pill ${pillClass}">${data}</span>`;
                        }
                        return data;
                    }
                }
            ],
            language: {
                search: "",
                searchPlaceholder: "Search invoices...",
                lengthMenu: "_MENU_",
                info: "Showing _START_ to _END_ of _TOTAL_ entries",
                infoEmpty: "Showing 0 to 0 of 0 entries",
                paginate: {
                    previous: '<i class="fa-solid fa-chevron-left"></i>',
                    next: '<i class="fa-solid fa-chevron-right"></i>'
                }
            },
            deferRender: true, // Improves performance with large datasets
            initComplete: function () {
                const api = this.api();
                const $container = $(api.table().container());

                // Remove "Show _ entries" and "Search:" labels
                $container.find('div.dataTables_length label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();

                $container.find('div.dataTables_filter label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();

                // Style length select
                $container.find('div.dataTables_length select').addClass('form-select form-select-sm');
                // Style filter input
                const $searchInput = $container.find('div.dataTables_filter input');
                $searchInput.addClass('form-control form-control-sm');

                if (currentTableState.search) {
                    $searchInput.val(currentTableState.search);
                }
                bindSearchInputSync($searchInput);
                bindPaginationSync(api);
                bindOrderSync(api, { defaultOrder: defaultOrder });
            }
        };

        if (currentTableState.search) {
            tableConfig.search = { search: currentTableState.search };
        }
        if (currentTableState.status) {
            const searchCols = [];
            while (searchCols.length < 6) searchCols.push(null);
            searchCols[6] = { search: '^' + currentTableState.status + '$', regex: true };
            tableConfig.searchCols = searchCols;
        }

        // Configure server-side processing if enabled
        if (isServerSide && ajaxUrl) {
            tableConfig.serverSide = true;
            tableConfig.processing = true;
            tableConfig.ajax = {
                url: ajaxUrl,
                cache: false,
                data: function (d) {
                    // Merge DataTables params with custom params
                    return $.extend({}, d, ajaxData);
                },
                error: function (xhr, error, thrown) {
                    console.error('DataTables server-side error:', xhr.status, error, thrown);
                    if (xhr.status === 500) {
                        console.error('Server error - check Rails logs for details');
                    }
                }
            };
            tableConfig.searchDelay = 400; // Delay search to reduce server requests
        }

        const dtInstance = $table.DataTable(tableConfig);
        setupInvoiceBulkActions(dtInstance, $table.attr('id'));

        const tableNode = $table[0];
        if (tableNode && !tableNode.dataset.responsiveFixAttached) {
            tableNode.addEventListener('click', function (e) {
                const downloadBtn = e.target.closest('.download-pdf');
                if (downloadBtn) {
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    const invoiceId = downloadBtn.getAttribute('data-id') || $(downloadBtn).data('id');
                    downloadInvoicePdf(invoiceId, $(downloadBtn));
                    return;
                }

                const previewBtn = e.target.closest('.preview-invoice');
                if (previewBtn) {
                    const isMobileOnly = previewBtn.classList.contains('preview-invoice-mobile');
                    const isMobileOrTablet = window.matchMedia('(max-width: 991.98px)').matches;
                    if (isMobileOnly && !isMobileOrTablet) {
                        // Desktop invoice link: allow standard navigation to invoice show page
                        return;
                    }
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    const invoiceId = previewBtn.getAttribute('data-id') || $(previewBtn).data('id');
                    openInvoicePreview(invoiceId);
                    return;
                }

                // Allow dropdown items, modal triggers, and turbo actions to bubble normally
                if (e.target.closest('.dropdown-menu, [data-turbo-method], [data-bs-toggle="modal"]')) {
                    return;
                }

                if (e.target.closest('a, button, input, select, textarea, .dropdown-toggle')) {
                    e.stopPropagation();
                }
            }, true);
            tableNode.dataset.responsiveFixAttached = 'true';
        }
    }

    // Helper to initialize visible table in an active tab pane
    function initVisibleTableInPane($mainPane) {
        if (!$mainPane || !$mainPane.length) return;
        const $visibleSubPane = $mainPane.find('.tab-content > .tab-pane.active, .tab-content > .tab-pane.show.active').first();
        const $table = $visibleSubPane.length ? $visibleSubPane.find('table[data-server-side="true"]') : $mainPane.find('table[data-server-side="true"]').first();
        if ($table.length) {
            initSingleDataTable($table);
        }
    }

    // Initialize table in currently active main tab and active subtab immediately
    const $initialActiveMainPane = $('#invoiceTabsContent > .tab-pane.active, #invoiceTabsContent > .tab-pane.show.active').first();
    initVisibleTableInPane($initialActiveMainPane);

    // Handle tab switch - initialize tables for newly activated tab on demand
    $('button[data-bs-toggle="tab"]').off('shown.bs.tab.invoice').on('shown.bs.tab.invoice', function (e) {
        const tabId = $(e.target).attr('id').replace('-tab', '');
        const targetPaneSelector = $(e.target).data('bs-target') || `#${tabId}`;
        const $targetPane = $(targetPaneSelector);

        // Find which subtab is active in the newly shown tab
        const $activeSubTab = $targetPane.find('.invoice-sub-tabs button.active');
        const isArchived = $activeSubTab.attr('id') && $activeSubTab.attr('id').includes('archived');
        updateUrlParams({ tab: tabId, subtab: isArchived ? 'archived' : null });

        // Synchronize card-filter active state in newly activated tab
        const currentStatus = getUrlParam('status') || '';
        syncCardFilterState(currentStatus);

        // Initialize ONLY the visible subtab table in this pane
        initVisibleTableInPane($targetPane);

        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 150);
    });

    // Click on subtab buttons immediately updates URL subtab param
    $(document).off('click.invoicesub', 'button[data-bs-toggle="pill"], .invoice-sub-tabs button').on('click.invoicesub', 'button[data-bs-toggle="pill"], .invoice-sub-tabs button', function () {
        const targetId = $(this).attr('id') || '';
        const isArchived = targetId.includes('archived');
        updateUrlParams({ subtab: isArchived ? 'archived' : null });
    });

    // Handle sub-tab switch (Active vs Archived) inside invoice table cards
    $(document).off('shown.bs.tab.invoicesub').on('shown.bs.tab.invoicesub', 'button[data-bs-toggle="pill"], .invoice-sub-tabs button', function (e) {
        const targetId = $(e.target).attr('id') || '';
        const isArchived = targetId.includes('archived');
        updateUrlParams({ subtab: isArchived ? 'archived' : null });

        const targetPaneSelector = $(e.target).data('bs-target');
        if (targetPaneSelector) {
            const $subPane = $(targetPaneSelector);
            const $table = $subPane.find('table[data-server-side="true"]');
            if ($table.length) {
                initSingleDataTable($table);
            }
        }
        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 100);
    });

    // Window resize
    $(window).off('resize.invoice').on('resize.invoice', function () {
        $.fn.dataTable
            .tables({ visible: true, api: true })
            .columns.adjust()
            .responsive.recalc();
    });

    // Helper to open invoice preview
    function openInvoicePreview(invoiceId) {
        if (!invoiceId) return;
        const $modal = $('#invoicePreviewModal');
        const $previewCard = $('#invoicePreviewCard');
        const modalEl = $modal[0];
        if (!modalEl) return;

        // Bind cleanup once: Bootstrap occasionally leaves a stale backdrop, blocking page clicks.
        if (!$modal.data('cleanup-bound')) {
            $modal.on('hidden.bs.modal', function () {
                $previewCard.empty();
                const hasOpenModal = $('.modal.show').length > 0;
                if (!hasOpenModal) {
                    $('body').removeClass('modal-open').css('padding-right', '');
                    $('.modal-backdrop').remove();
                }
            });
            $modal.data('cleanup-bound', true);
        }

        $previewCard.html('<div class="text-center p-5"><div class="spinner-border text-primary" role="status"></div><p class="mt-2">Loading preview...</p></div>');
        const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
        modal.show();

        $.ajax({
            url: `/invoices/${invoiceId}/pdf_partial`,
            method: 'GET',
            success: function (data) {
                // Render the partial into the modal and enforce light theme
                $previewCard.addClass('force-light-mode').attr('data-theme', 'light').attr('data-bs-theme', 'light');
                $previewCard.html(data);

                const $invoiceCard = $previewCard.find('#invoice_card');
                $invoiceCard.addClass('force-light-mode').attr('data-theme', 'light').attr('data-bs-theme', 'light');
                $invoiceCard.find('.invoice-container').addClass('force-light-mode').attr('data-theme', 'light').attr('data-bs-theme', 'light');

                // Set the modal title based on the invoice type from the returned HTML if possible
                const category = $invoiceCard.data('category');
                if (category) {
                    const title = category.charAt(0).toUpperCase() + category.slice(1).replace('_', ' ');
                    $modal.find('.modal-title').text(title + ' Preview');
                } else {
                    $modal.find('.modal-title').text('Preview');
                }

                updatePdfPreviewScale();
            },
            error: function () {
                $previewCard.html('<div class="alert alert-danger">Failed to load preview.</div>');
            }
        });
    }

    // Preview handling
    $(document).off('click.invoicePreview', '.preview-invoice').on('click.invoicePreview', '.preview-invoice', function (e) {
        const isMobileOnly = $(this).hasClass('preview-invoice-mobile');
        const isMobileOrTablet = window.matchMedia('(max-width: 991.98px)').matches;
        if (isMobileOnly && !isMobileOrTablet) {
            // Desktop invoice link: allow standard navigation to invoice show page
            return;
        }
        e.preventDefault();
        const invoiceId = $(this).data('id');
        openInvoicePreview(invoiceId);
    });

    // Helper to download invoice as PDF
    function downloadInvoicePdf(invoiceId, $trigger) {
        if (!invoiceId) {
            console.error('Invoice ID is missing for PDF download');
            return;
        }

        if ($trigger && $trigger.data('downloading')) return;
        if ($trigger) $trigger.data('downloading', true);

        const htmlElement = document.documentElement;
        const currentDataTheme = htmlElement.getAttribute('data-theme');
        const currentBSTheme = htmlElement.getAttribute('data-bs-theme');

        // Disable transitions temporarily during PDF capture to avoid rendering glitches
        const noTransitionStyle = document.createElement('style');
        noTransitionStyle.appendChild(
            document.createTextNode(
                `* {
                   -webkit-transition: none !important;
                   -moz-transition: none !important;
                   -o-transition: none !important;
                   -ms-transition: none !important;
                   transition: none !important;
                }`
            )
        );
        document.head.appendChild(noTransitionStyle);

        // Force light mode on document root for high-fidelity light theme PDF export
        htmlElement.setAttribute('data-theme', 'light');
        htmlElement.setAttribute('data-bs-theme', 'light');

        let $overlay = $('#pdf-loading-overlay');
        if (!$overlay.length) {
            $overlay = $(`
                <div id="pdf-loading-overlay" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; z-index: 999999; display: flex; flex-direction: column; justify-content: center; align-items: center; background-color: rgba(0, 0, 0, 0.65); color: #ffffff;">
                    <div class="spinner-border text-primary pdf-spinner" style="width: 4rem; height: 4rem;" role="status">
                        <span class="visually-hidden">Loading...</span>
                    </div>
                    <h3 class="mt-4 pdf-text">Downloading PDF...</h3>
                    <p class="pdf-subtext" style="color: #dee2e6;">Please do not close this window.</p>
                </div>
            `).appendTo('body');
        } else {
            $overlay.css({ 'background-color': 'rgba(0, 0, 0, 0.65)', 'color': '#ffffff' });
            $overlay.find('.pdf-spinner').removeClass('text-light').addClass('text-primary');
            $overlay.find('.pdf-subtext').css('color', '#dee2e6');
        }

        $overlay.show();

        const cleanupAndRestore = () => {
            if (currentDataTheme) htmlElement.setAttribute('data-theme', currentDataTheme);
            else htmlElement.removeAttribute('data-theme');

            if (currentBSTheme) htmlElement.setAttribute('data-bs-theme', currentBSTheme);
            else htmlElement.removeAttribute('data-bs-theme');

            if (document.head.contains(noTransitionStyle)) {
                const _ = window.getComputedStyle(noTransitionStyle).opacity;
                document.head.removeChild(noTransitionStyle);
            }

            if ($trigger) $trigger.data('downloading', false);
            $overlay.hide();
        };

        $.get(`/invoices/${invoiceId}/pdf_partial`, function (html) {
            const temp = document.createElement('div');
            temp.classList.add('force-light-mode', 'invoice-card', 'invoice-container');
            temp.setAttribute('data-theme', 'light');
            temp.setAttribute('data-bs-theme', 'light');

            // Parse HTML safely using DOMParser
            const parser = new DOMParser();
            const doc = parser.parseFromString(html, 'text/html');
            const parsedCard = doc.querySelector('#invoice_card');

            if (!parsedCard) {
                showInvoiceToast('Invoice HTML not found', 'danger');
                cleanupAndRestore();
                return;
            }

            temp.appendChild(parsedCard);
            temp.style.position = 'absolute';
            temp.style.left = '-9999px';
            temp.style.top = '0';
            temp.style.width = '1000px';
            temp.style.backgroundColor = '#ffffff';
            temp.style.color = '#212529';
            temp.style.opacity = '0';
            temp.style.pointerEvents = 'none';
            document.body.appendChild(temp);

            let invoice = parsedCard;

            // Create a clean container for the invoice content
            const content = document.createElement('div');
            content.classList.add('invoice-card', 'force-light-mode', 'invoice-container');
            content.setAttribute('data-theme', 'light');
            content.setAttribute('data-bs-theme', 'light');
            content.style.backgroundColor = '#ffffff';
            content.style.color = '#212529';
            while (invoice.firstChild) {
                content.appendChild(invoice.firstChild);
            }

            // Replace the original card-wrapped content with our clean container
            invoice.parentNode.replaceChild(content, invoice);
            invoice = content;

            // Apply page break rules
            const noBreakElements = invoice.querySelectorAll('table tr, .card, .pdf-no-break, .payment-terms-box, .message-box, .totals-section, .attachment-card, .line-item, .price-adjustment-row');
            noBreakElements.forEach(el => {
                el.style.pageBreakInside = 'avoid';
                el.style.breakInside = 'avoid';
            });

            const tables = invoice.querySelectorAll('table');
            tables.forEach(table => {
                table.style.pageBreakInside = 'auto';
            });

            // Specific styling for PDF: remove card borders and bg-light from attachment sections
            const attachmentContainers = invoice.querySelectorAll('#attachments-section, #modal_new_attachments_preview, #persisted-attachments-container');
            attachmentContainers.forEach(container => {
                container.querySelectorAll('.card').forEach(card => {
                    card.style.border = '1px solid white';
                    card.style.boxShadow = 'none';
                });
                container.querySelectorAll('.bg-light').forEach(el => {
                    el.classList.remove('bg-light');
                    el.style.backgroundColor = 'transparent';
                });
            });

            // Remove Download buttons from attachments
            invoice.querySelectorAll('a.btn.btn-outline-primary, a.btn.btn-sm.btn-outline-primary').forEach(btn => {
                if (btn.textContent.trim() === 'Download') {
                    btn.remove();
                }
            });

            // Remove non-renderable elements (embed, object, iframe) that cause html2canvas to fail
            invoice.querySelectorAll('embed, object, iframe').forEach(el => el.remove());

            // Prevent cropping with slight scaling
            invoice.style.transform = 'scale(0.99)';
            invoice.style.transformOrigin = 'top left';

            // Wait for all images to load before generating PDF
            const images = Array.from(invoice.querySelectorAll('img'));
            const imagePromises = images.map(img => {
                if (img.complete) return Promise.resolve();
                return new Promise(resolve => {
                    img.onload = img.onerror = resolve;
                });
            });

            Promise.all([...imagePromises, loadHtml2Pdf()]).then(() => {
                // Today's date for filename
                const today = new Date();
                const yyyy = today.getFullYear();
                const mm = String(today.getMonth() + 1).padStart(2, '0');
                const dd = String(today.getDate()).padStart(2, '0');
                const dateStr = `${yyyy}-${mm}-${dd}`;
                const invoiceNumber = (parsedCard.getAttribute('data-invoice-number') || invoiceId).toString().replace(/[^a-zA-Z0-9_-]/g, '_');

                const opt = {
                    margin: [9, 9, 9, 9],
                    filename: `${dateStr}-invoice-${invoiceNumber}.pdf`,
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
                        avoid: ['tr', '.card', 'table', '.no-break', '.pdf-no-break', '.payment-terms-box', '.message-box', '.totals-section', '.attachment-card', '.line-item', '.price-adjustment-row']
                    }
                };

                if (typeof html2pdf === 'undefined') {
                    throw new Error('html2pdf is not available on the page');
                }

                html2pdf().set(opt).from(invoice).save().then(() => {
                    if (document.body.contains(temp)) document.body.removeChild(temp);
                    cleanupAndRestore();
                }).catch((error) => {
                    console.error('Error generating PDF:', error);
                    if (document.body.contains(temp)) document.body.removeChild(temp);
                    cleanupAndRestore();
                    showInvoiceToast('Failed to generate PDF. Please try again.', 'danger');
                });
            }).catch((error) => {
                console.error('Error preparing PDF:', error);
                if (document.body.contains(temp)) document.body.removeChild(temp);
                cleanupAndRestore();
                showInvoiceToast('Failed to prepare PDF. Please try again.', 'danger');
            });
        }).fail(function (xhr, status, error) {
            console.error('Error fetching invoice:', error);
            cleanupAndRestore();
            showInvoiceToast('Failed to load invoice data. Please try again.', 'danger');
        });
    }

    // PDF Download delegated listener for elements outside the table
    $(document).off('click.invoiceDownload', '.download-pdf').on('click.invoiceDownload', '.download-pdf', function (e) {
        e.preventDefault();
        const invoiceId = $(this).data('id') || $(this).attr('data-id');
        downloadInvoicePdf(invoiceId, $(this));
    });

    // Card filter
    $(document).off("click.filter", ".card-filter").on("click.filter", ".card-filter", function () {
        const $this = $(this);
        const tableSelector = $this.data("table");
        const status = ($this.data("status") || '').toString().trim().toLowerCase();
        const isAlreadyActive = $this.hasClass("active");

        // Toggle behavior: if clicking an already active non-total card, deselect back to total ("")
        let targetStatus = status;
        if (isAlreadyActive && status) {
            targetStatus = "";
        }

        updateUrlParams({ status: targetStatus || null }, { clearPage: true });
        syncCardFilterState(targetStatus);

        const $mainPane = $this.closest('.tab-pane');
        const $tables = $mainPane.find('table.invoice-datatable');

        if ($tables.length && $.fn.DataTable) {
            $tables.each(function () {
                if ($.fn.DataTable.isDataTable(this)) {
                    const table = $(this).DataTable();
                    const headers = table.columns().header().toArray();
                    const statusColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('status'));
                    const targetCol = statusColIdx !== -1 ? statusColIdx : 6;
                    if (targetStatus) {
                        table.column(targetCol).search('^' + targetStatus + '$', true, false, true).draw();
                    } else {
                        table.column(targetCol).search("").draw();
                    }
                }
            });
        } else if ($.fn.DataTable && tableSelector && $(tableSelector).length) {
            const table = $(tableSelector).DataTable();
            if (targetStatus) {
                table.column(6).search('^' + targetStatus + '$', true, false, true).draw();
            } else {
                table.column(6).search("").draw();
            }
        }
    });

    // File list handler for dynamic modals
    $(document).off('change', '.file-upload-input').on('change', '.file-upload-input', function () {
        const $input = $(this);
        const targetSelector = $input.data('list-target');
        const isMultiple = $input.data('multiple');
        const $list = $(targetSelector).empty();

        const files = Array.from(this.files);
        if (!files.length) return;

        // Check for HEIC files
        const heicExtensions = ['.heic', '.heif'];
        const heicMimeTypes = ['image/heic', 'image/heif'];
        const invalidFiles = files.filter(file => {
            const ext = file.name.toLowerCase().substring(file.name.lastIndexOf('.'));
            return heicExtensions.includes(ext) || heicMimeTypes.includes(file.type.toLowerCase());
        });

        if (invalidFiles.length > 0) {
            const fileNames = invalidFiles.map(f => f.name).join(', ');
            if (window.showFlashMessage) {
                window.showFlashMessage(`HEIC files are not supported: ${fileNames}<br>Please convert to JPG, PNG, or PDF.`, 'danger');
            }
            $input.val('');
            return;
        }

        const displayFiles = isMultiple ? files : [files[0]];

        if (!isMultiple && displayFiles.length === 1) {
            $list.addClass('file-preview-single');
        } else {
            $list.addClass('file-preview-grid');
        }

        displayFiles.forEach(file => {
            const isImage = file.type.startsWith('image/');
            const isPDF = file.type === 'application/pdf';
            let previewHTML = '';

            if (isImage) {
                const objectUrl = URL.createObjectURL(file);
                previewHTML = `
                    <li class="list-group-item file-preview-item p-0 border-0">
                        <div class="file-preview-container">
                            <img src="${objectUrl}" alt="${file.name}" class="file-preview-image" title="${file.name}">
                            <div class="file-preview-name">${file.name}</div>
                        </div>
                    </li>
                `;
            } else if (isPDF) {
                const objectUrl = URL.createObjectURL(file);
                previewHTML = `
                    <li class="list-group-item file-preview-item p-0 border-0">
                        <div class="file-preview-container">
                            <embed src="${objectUrl}" type="application/pdf" class="w-100 rounded" style="height: 350px; min-height: 40vh;" />
                            <div class="file-preview-name text-center small p-1 text-truncate" title="${file.name}">${file.name}</div>
                        </div>
                    </li>
                `;
            } else {
                const size = Math.round(file.size / 1024);
                previewHTML = `
                    <li class="list-group-item d-flex justify-content-between align-items-center file-list-item">
                        <span class="file-name-wrapper" title="${file.name}">${file.name}</span>
                        <span class="badge bg-secondary rounded-pill ms-2 flex-shrink-0">${size} KB</span>
                    </li>
                `;
            }

            $list.append(previewHTML);
        });
    });
}

document.addEventListener("turbo:load", initInvoicePage);
document.addEventListener("DOMContentLoaded", initInvoicePage);
window.addEventListener("popstate", function () {
    if (window.location.pathname.includes("/invoices")) {
        initInvoicePage();
    }
});

// Init immediately to catch late-loading scripts
initInvoicePage();
