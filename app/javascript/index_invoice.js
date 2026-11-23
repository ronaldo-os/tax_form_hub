import { updatePdfPreviewScale } from './invoice_preview';
import { initInvoiceExport, showInvoiceToast } from './invoices_export';
import { setupInvoiceBulkActions } from './invoice_bulk';
import { initDataTableColumnVisibility } from './datatable_column_visibility';
import { hideSkeleton, setupSkeletonSafetyFallback } from './skeleton_loader';
import { 
    getInitialTableState, 
    updateUrlParams, 
    activateTabElement,
    bindSearchInputSync, 
    bindPaginationSync, 
    resolveSortOrder, 
    bindOrderSync, 
    getUrlParam 
} from './table_url_sync';

const VALID_INVOICE_TABS = ['sales-invoices', 'purchase-invoices', 'sent-quotes', 'received-quotes'];

function getStoredInvoiceSubTab(tabId) {
    try {
        const val = sessionStorage.getItem(`invoice_subtab_${tabId}`);
        return val === 'archived' ? 'archived' : 'active';
    } catch (e) {
        return 'active';
    }
}

function setStoredInvoiceSubTab(tabId, subtab) {
    if (!VALID_INVOICE_TABS.includes(tabId)) return;
    try {
        sessionStorage.setItem(`invoice_subtab_${tabId}`, subtab === 'archived' ? 'archived' : 'active');
    } catch (e) {
        // Ignore storage errors
    }
}

function syncInvoiceDropdownLinks(tabId) {
    if (!VALID_INVOICE_TABS.includes(tabId)) return;
    const dropdownMenu = document.querySelector('#createDocumentDropdown + .dropdown-menu');
    if (!dropdownMenu) return;
    dropdownMenu.querySelectorAll('a.dropdown-item').forEach((link) => {
        try {
            const url = new URL(link.href, window.location.origin);
            url.searchParams.set('tab', tabId);
            link.href = url.pathname + url.search;
        } catch (err) {
            // Ignore malformed URLs
        }
    });
}

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

    setupSkeletonSafetyFallback([['invoices_skeleton', 'invoices_content']], 1000);

    const initial = getInitialTableState();

    // Restore active tab if specified in URL and not already active
    const targetTab = VALID_INVOICE_TABS.includes(initial.tab) ? initial.tab : 'sales-invoices';
    const mainTabBtn = document.getElementById(`${targetTab}-tab`);
    if (mainTabBtn) {
        activateTabElement(mainTabBtn);
        syncInvoiceDropdownLinks(targetTab);
    }

    // Restore subtab (Active vs Archived) in the active tab and background tabs
    const isTargetArchived = initial.subtab === 'archived';
    setStoredInvoiceSubTab(targetTab, isTargetArchived ? 'archived' : 'active');

    VALID_INVOICE_TABS.forEach((tabId) => {
        const $pane = $(`#${tabId}`);
        if (!$pane.length) return;
        const isArchived = tabId === targetTab ? isTargetArchived : (getStoredInvoiceSubTab(tabId) === 'archived');
        const subTabSelector = isArchived ? '.invoice-sub-tabs button[id$="-archived-tab"]' : '.invoice-sub-tabs button[id$="-active-tab"]';
        const subTabBtn = $pane.find(subTabSelector)[0];
        if (subTabBtn) {
            activateTabElement(subTabBtn);
        }
    });

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
                initDataTableColumnVisibility(api);
                hideSkeleton('invoices_skeleton', 'invoices_content');
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
                    if (error === 'abort' || (xhr && xhr.status === 0)) {
                        return;
                    }
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

    // Handle main tab switch - immediately update URL on click and initialize tables on shown
    $('#submissionTabs button[data-bs-toggle="tab"]')
        .off('click.invoicetab shown.bs.tab.invoice')
        .on('click.invoicetab shown.bs.tab.invoice', function (e) {
            const tabId = ($(e.currentTarget).attr('id') || '').replace('-tab', '');
            if (!VALID_INVOICE_TABS.includes(tabId)) return;

            const targetPaneSelector = $(e.currentTarget).data('bs-target') || `#${tabId}`;
            const $targetPane = $(targetPaneSelector);

            // Find which subtab is active in the newly shown tab
            const $activeSubTab = $targetPane.find('.invoice-sub-tabs button.active');
            const isArchived = ($activeSubTab.attr('id') && $activeSubTab.attr('id').includes('archived')) || getStoredInvoiceSubTab(tabId) === 'archived';
            updateUrlParams({ tab: tabId, subtab: isArchived ? 'archived' : null });
            syncInvoiceDropdownLinks(tabId);

            if (e.type === 'shown') {
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
            }
        });

    // Click on subtab buttons immediately updates URL subtab param and session storage
    $(document)
        .off('click.invoicesub', '.invoice-sub-tabs button[data-bs-toggle="pill"], .invoice-sub-tabs button')
        .on('click.invoicesub', '.invoice-sub-tabs button[data-bs-toggle="pill"], .invoice-sub-tabs button', function () {
            const targetId = $(this).attr('id') || '';
            const isArchived = targetId.includes('archived');
            const $mainPane = $(this).closest('#invoiceTabsContent > .tab-pane');
            const mainTabId = $mainPane.attr('id');
            if (mainTabId) {
                setStoredInvoiceSubTab(mainTabId, isArchived ? 'archived' : 'active');
            }
            updateUrlParams({ subtab: isArchived ? 'archived' : null });
        });

    // Handle sub-tab switch (Active vs Archived) inside invoice table cards
    $(document)
        .off('shown.bs.tab.invoicesub')
        .on('shown.bs.tab.invoicesub', '.invoice-sub-tabs button[data-bs-toggle="pill"], .invoice-sub-tabs button', function (e) {
            const targetId = $(e.target).attr('id') || '';
            const isArchived = targetId.includes('archived');
            const $mainPane = $(e.target).closest('#invoiceTabsContent > .tab-pane');
            const mainTabId = $mainPane.attr('id');
            if (mainTabId) {
                setStoredInvoiceSubTab(mainTabId, isArchived ? 'archived' : 'active');
            }
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

    // File list handler for dynamic modals and drag-and-drop dropzones
    $(document).off('change.invoice_tax_dropzone', '.tax-file-dropzone .file-upload-input').on('change.invoice_tax_dropzone', '.tax-file-dropzone .file-upload-input', function () {
        const $input = $(this);
        const targetSelector = $input.data('list-target');
        const isMultiple = $input.data('multiple') === true || $input.data('multiple') === 'true';
        const listEl = targetSelector ? document.querySelector(targetSelector) : null;
        const $dropzone = $input.closest('.file-dropzone');

        if (listEl) {
            listEl.replaceChildren();
            listEl.classList.remove('file-preview-single', 'file-preview-grid');
        }

        const files = Array.from(this.files || []);
        if (!files.length) {
            $dropzone.removeClass('has-files is-dragover');
            $dropzone.find('.dropzone-status-text').remove();
            $dropzone.find('.dropzone-default-text').removeClass('d-none');
            return;
        }

        // Check for HEIC files
        const heicExtensions = ['.heic', '.heif'];
        const heicMimeTypes = ['image/heic', 'image/heif'];
        const invalidFiles = files.filter(file => {
            const dotIdx = file.name.lastIndexOf('.');
            const ext = dotIdx >= 0 ? file.name.toLowerCase().substring(dotIdx) : '';
            return heicExtensions.includes(ext) || heicMimeTypes.includes((file.type || '').toLowerCase());
        });

        if (invalidFiles.length > 0) {
            const fileNames = invalidFiles.map(f => f.name).join(', ');
            if (window.showFlashMessage) {
                window.showFlashMessage(`HEIC files are not supported: ${fileNames}. Please convert to JPG, PNG, or PDF.`, 'danger');
            }
            $input.val('');
            $dropzone.removeClass('has-files is-dragover');
            $dropzone.find('.dropzone-status-text').remove();
            $dropzone.find('.dropzone-default-text').removeClass('d-none');
            return;
        }

        const displayFiles = isMultiple ? files : [files[0]];

        // Update dropzone UI state safely without innerHTML
        $dropzone.addClass('has-files');
        $dropzone.find('.dropzone-default-text').addClass('d-none');
        const countText = isMultiple
            ? `${displayFiles.length} file${displayFiles.length > 1 ? 's' : ''} selected`
            : `1 file selected (${displayFiles[0].name})`;

        let statusEl = $dropzone.find('.dropzone-status-text')[0];
        if (!statusEl) {
            statusEl = document.createElement('div');
            statusEl.className = 'dropzone-status-text text-success fw-semibold small mt-1';
            const contentEl = $dropzone.find('.dropzone-content')[0];
            if (contentEl) contentEl.appendChild(statusEl);
        }
        statusEl.replaceChildren();
        const checkIcon = document.createElement('i');
        checkIcon.className = 'fa-solid fa-circle-check me-1';
        statusEl.appendChild(checkIcon);
        statusEl.appendChild(document.createTextNode(countText));

        const subHint = document.createElement('span');
        subHint.className = 'text-muted fw-normal d-block small';
        subHint.textContent = 'Click or drag & drop to replace';
        statusEl.appendChild(subHint);

        if (!listEl) return;

        if (!isMultiple && displayFiles.length === 1) {
            listEl.classList.add('file-preview-single');
        } else {
            listEl.classList.add('file-preview-grid');
        }

        const inputId = $input.attr('id') ? `#${$input.attr('id')}` : '';

        displayFiles.forEach((file, index) => {
            const isImage = file.type.startsWith('image/');
            const isPDF = file.type === 'application/pdf';

            const removeBtn = document.createElement('button');
            removeBtn.type = 'button';
            removeBtn.className = 'btn btn-remove-preview-file';
            removeBtn.dataset.fileIndex = String(index);
            removeBtn.dataset.inputTarget = inputId;
            removeBtn.title = 'Remove file';
            removeBtn.setAttribute('aria-label', `Remove ${file.name}`);
            const xIcon = document.createElement('i');
            xIcon.className = 'fa-solid fa-xmark';
            removeBtn.appendChild(xIcon);

            if (isImage) {
                const objectUrl = URL.createObjectURL(file);
                const li = document.createElement('li');
                li.className = 'list-group-item file-preview-item p-0 border-0';
                li.appendChild(removeBtn);

                const container = document.createElement('div');
                container.className = 'file-preview-container';

                const img = document.createElement('img');
                img.src = objectUrl;
                img.alt = file.name;
                img.title = file.name;
                img.className = 'file-preview-image';

                const nameDiv = document.createElement('div');
                nameDiv.className = 'file-preview-name';
                nameDiv.textContent = file.name;

                container.appendChild(img);
                container.appendChild(nameDiv);
                li.appendChild(container);
                listEl.appendChild(li);
            } else if (isPDF) {
                const objectUrl = URL.createObjectURL(file);
                const li = document.createElement('li');
                li.className = 'list-group-item file-preview-item p-0 border-0';
                li.appendChild(removeBtn);

                const container = document.createElement('div');
                container.className = 'file-preview-container';

                const embed = document.createElement('embed');
                embed.src = objectUrl;
                embed.type = 'application/pdf';
                embed.className = 'w-100 rounded';
                embed.style.height = '350px';
                embed.style.minHeight = '40vh';

                const nameDiv = document.createElement('div');
                nameDiv.className = 'file-preview-name text-center small p-1 text-truncate';
                nameDiv.title = file.name;
                nameDiv.textContent = file.name;

                container.appendChild(embed);
                container.appendChild(nameDiv);
                li.appendChild(container);
                listEl.appendChild(li);
            } else {
                const size = Math.round(file.size / 1024);
                const li = document.createElement('li');
                li.className = 'list-group-item d-flex justify-content-between align-items-center file-list-item file-preview-item';

                const nameSpan = document.createElement('span');
                nameSpan.className = 'file-name-wrapper';
                nameSpan.title = file.name;
                nameSpan.textContent = file.name;

                const rightWrap = document.createElement('span');
                rightWrap.className = 'd-inline-flex align-items-center gap-2 ms-2 flex-shrink-0';

                const sizeBadge = document.createElement('span');
                sizeBadge.className = 'badge bg-secondary rounded-pill';
                sizeBadge.textContent = `${size} KB`;

                removeBtn.style.position = 'static';
                rightWrap.appendChild(sizeBadge);
                rightWrap.appendChild(removeBtn);

                li.appendChild(nameSpan);
                li.appendChild(rightWrap);
                listEl.appendChild(li);
            }
        });
    });

    // Drag-and-drop & keyboard events for tax document dropzones on Invoices page
    $(document).off('dragenter.invoice_tax_dropzone dragover.invoice_tax_dropzone', '.tax-file-dropzone')
               .on('dragenter.invoice_tax_dropzone dragover.invoice_tax_dropzone', '.tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        $(this).addClass('is-dragover');
    });

    $(document).off('dragleave.invoice_tax_dropzone dragend.invoice_tax_dropzone', '.tax-file-dropzone')
               .on('dragleave.invoice_tax_dropzone dragend.invoice_tax_dropzone', '.tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        const related = e.originalEvent && e.originalEvent.relatedTarget;
        if (!related || !this.contains(related)) {
            $(this).removeClass('is-dragover');
        }
    });

    $(document).off('drop.invoice_tax_dropzone', '.tax-file-dropzone')
               .on('drop.invoice_tax_dropzone', '.tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        const $dropzone = $(this);
        $dropzone.removeClass('is-dragover');

        const droppedFiles = e.originalEvent && e.originalEvent.dataTransfer && e.originalEvent.dataTransfer.files;
        if (!droppedFiles || !droppedFiles.length) return;

        const targetSelector = $dropzone.data('target-input');
        const inputEl = targetSelector ? document.querySelector(targetSelector) : $dropzone.find('input[type="file"]')[0];
        if (!inputEl) return;

        const isMultiple = $(inputEl).data('multiple') === true || $(inputEl).data('multiple') === 'true';
        const dt = new DataTransfer();
        if (isMultiple) {
            Array.from(droppedFiles).forEach(file => dt.items.add(file));
        } else {
            dt.items.add(droppedFiles[0]);
        }
        inputEl.files = dt.files;
        $(inputEl).trigger('change');
    });

    $(document).off('keydown.invoice_tax_dropzone', '.tax-file-dropzone')
               .on('keydown.invoice_tax_dropzone', '.tax-file-dropzone', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            const targetSelector = $(this).data('target-input');
            const inputEl = targetSelector ? document.querySelector(targetSelector) : $(this).find('input[type="file"]')[0];
            if (inputEl) inputEl.click();
        }
    });

    $(document).off('click.invoice_tax_dropzone', '.btn-remove-preview-file')
               .on('click.invoice_tax_dropzone', '.btn-remove-preview-file', function (e) {
        e.preventDefault();
        e.stopPropagation();

        const indexToRemove = Number($(this).data('file-index'));
        const inputSelector = $(this).data('input-target');
        const inputEl = inputSelector ? document.querySelector(inputSelector) : null;
        if (!inputEl || !inputEl.files) return;

        const dt = new DataTransfer();
        Array.from(inputEl.files).forEach((file, idx) => {
            if (idx !== indexToRemove) {
                dt.items.add(file);
            }
        });
        inputEl.files = dt.files;
        $(inputEl).trigger('change');
    });
}

// Handle 'Pay Full Balance' button in payment modals
$(document).on('click', '.fill-full-balance-btn', function (e) {
    e.preventDefault();
    const targetSelector = $(this).data('target');
    const balance = $(this).data('balance');
    if (targetSelector && balance !== undefined) {
        $(targetSelector).val(balance).trigger('change');
    }
});

// Synchronize redirect_url for Submit Tax Documents modal on invoices page
$(document).on('show.bs.modal', 'div[id^="submitTaxModal-"]', function () {
    const $modal = $(this);
    const $redirectInput = $modal.find('input[name="redirect_url"]');
    if ($redirectInput.length) {
        try {
            const url = new URL(window.location.href);
            url.searchParams.delete('open_modal');
            url.searchParams.delete('open_submit_modal');
            const currentTab = getUrlParam('tab');
            if (currentTab) {
                url.searchParams.set('tab', currentTab);
            }
            $redirectInput.val(url.pathname + (url.search ? url.search : ''));
        } catch (e) {}
    }
});

$(document).on('submit', 'div[id^="submitTaxModal-"] form', function () {
    const $form = $(this);
    const $redirectInput = $form.find('input[name="redirect_url"]');
    if ($redirectInput.length) {
        try {
            const url = new URL(window.location.href);
            url.searchParams.delete('open_modal');
            url.searchParams.delete('open_submit_modal');
            const currentTab = getUrlParam('tab');
            if (currentTab) {
                url.searchParams.set('tab', currentTab);
            }
            $redirectInput.val(url.pathname + (url.search ? url.search : ''));
        } catch (e) {}
    }
});

document.addEventListener("turbo:load", initInvoicePage);
document.addEventListener("DOMContentLoaded", initInvoicePage);
window.addEventListener("popstate", function () {
    if (window.location.pathname.includes("/invoices")) {
        initInvoicePage();
    }
});

// Init immediately to catch late-loading scripts
initInvoicePage();
