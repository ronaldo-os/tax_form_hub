function initInvoicePage() {
    if (!window.location.pathname.includes("/invoices")) return;

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
                        borderRadius: 5,
                        barThickness: filteredData.length > 3 ? 4 : 8, // Thicker bars if fewer months to avoid looking like a 'dash'
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

    // Initialize DataTables - Support both client-side and server-side processing
    const tableSelectors = '#sales-table, #purchases-table, #sales-archived-table, #purchases-archived-table, #sent-quotes-table, #sent-quotes-archived-table, #received-quotes-table, #received-quotes-archived-table';

    $(tableSelectors).each(function() {
        const $table = $(this);
        // Data attributes are strings, not booleans - check for "true" string
        const isServerSide = $table.attr('data-server-side') === 'true';
        const ajaxUrl = $table.data('ajax-url');
        // Parse the JSON data attribute
        let ajaxData = {};
        try {
            const ajaxDataAttr = $table.attr('data-ajax-data');
            if (ajaxDataAttr) {
                ajaxData = JSON.parse(ajaxDataAttr);
            }
        } catch (e) {
            console.warn('Failed to parse data-ajax-data:', e);
        }

        const tableConfig = {
            responsive: true,
            autoWidth: false,
            destroy: true, // Important for Turbo
            pageLength: 25,
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
            }
        };

        // Configure server-side processing if enabled
        if (isServerSide && ajaxUrl) {
            tableConfig.serverSide = true;
            tableConfig.processing = true;
            tableConfig.ajax = {
                url: ajaxUrl,
                cache: false,
                data: function(d) {
                    // Merge DataTables params with custom params
                    return $.extend({}, d, ajaxData);
                },
                error: function(xhr, error, thrown) {
                    console.error('DataTables server-side error:', xhr.status, error, thrown);
                    if (xhr.status === 500) {
                        console.error('Server error - check Rails logs for details');
                    }
                }
            };
            tableConfig.searchDelay = 400; // Delay search to reduce server requests
        }

        $table.DataTable(tableConfig);
    });

    // Handle tab switch - Unbind first to prevent duplicates
    $('button[data-bs-toggle="tab"]').off('shown.bs.tab.invoice').on('shown.bs.tab.invoice', function (e) {
        const tabId = $(e.target).attr('id').replace('-tab', '');
        const url = new URL(window.location);
        url.searchParams.set('tab', tabId);
        window.history.replaceState({}, '', url);

        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 200);
    });

    // Window resize
    $(window).off('resize.invoice').on('resize.invoice', function () {
        $.fn.dataTable
            .tables({ visible: true, api: true })
            .columns.adjust()
            .responsive.recalc();
    });

    // Preview handling
    $(document).off('click.invoicePreview', '.preview-invoice').on('click.invoicePreview', '.preview-invoice', function (e) {
        e.preventDefault();
        const invoiceId = $(this).data('id');
        const $modal = $('#invoicePreviewModal');
        const $previewCard = $('#invoicePreviewCard');
        const modalEl = $modal[0];

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
                // Render the partial into the modal
                $previewCard.html(data);

                // Set the modal title based on the invoice type from the returned HTML if possible
                const category = $previewCard.find('#invoice_card').data('category');
                if (category) {
                    const title = category.charAt(0).toUpperCase() + category.slice(1).replace('_', ' ');
                    $modal.find('.modal-title').text(title + ' Preview');
                }
            },
            error: function () {
                $previewCard.html('<div class="alert alert-danger">Failed to load preview.</div>');
            }
        });
    });

    // PDF Download
    $(document).off('click.invoiceDownload', '.download-pdf').on('click.invoiceDownload', '.download-pdf', function (e) {
        e.preventDefault();
        const invoiceId = $(this).data('id');
        const $trigger = $(this);

        if ($trigger.data('downloading')) return;
        $trigger.data('downloading', true);

        $.get(`/invoices/${invoiceId}/pdf_partial`, function (html) {
            const temp = document.createElement('div');
            temp.classList.add('force-light-mode', 'invoice-card');
            temp.setAttribute('data-theme', 'light');
            temp.setAttribute('data-bs-theme', 'light');
            temp.innerHTML = html;
            temp.style.position = 'absolute';
            temp.style.left = '-9999px';
            temp.style.width = '1000px';
            temp.style.background = 'white';
            temp.style.color = 'black';
            temp.style.opacity = '0';
            temp.style.pointerEvents = 'none';
            document.body.appendChild(temp);

            let invoice = temp.querySelector("#invoice_card");

            if (!invoice) {
                alert("Invoice HTML not found");
                if (document.body.contains(temp)) document.body.removeChild(temp);
                return;
            }

            // Create a clean container for the invoice content
            const content = document.createElement('div');
            content.classList.add('invoice-card');
            while (invoice.firstChild) {
                content.appendChild(invoice.firstChild);
            }

            // Replace the original card-wrapped content with our clean container
            invoice.parentNode.replaceChild(content, invoice);
            invoice = content;

            // Apply page break rules
            const tableRows = invoice.querySelectorAll('table tr');
            tableRows.forEach(row => {
                row.style.pageBreakInside = 'avoid';
                row.style.breakInside = 'avoid';
            });

            const tables = invoice.querySelectorAll('table');
            tables.forEach(table => {
                table.style.pageBreakInside = 'auto';
            });

            const cards = invoice.querySelectorAll('.card');
            cards.forEach(card => {
                card.style.pageBreakInside = 'avoid';
                card.style.breakInside = 'avoid';
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

            Promise.all(imagePromises).then(() => {
                // Today's date for filename
                const today = new Date();
                const yyyy = today.getFullYear();
                const mm = String(today.getMonth() + 1).padStart(2, '0');
                const dd = String(today.getDate()).padStart(2, '0');
                const dateStr = `${yyyy}-${mm}-${dd}`;

                const opt = {
                    margin: [9, 9, 9, 9],
                    filename: `${dateStr}-invoice-${invoiceId}.pdf`,
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
                        avoid: ['tr', '.card', 'table', '.no-break']
                    }
                };

                if (typeof html2pdf === 'undefined') {
                    throw new Error('html2pdf is not available on the page');
                }

                const htmlElement = document.documentElement;
                const currentDataTheme = htmlElement.getAttribute('data-theme');
                const currentBSTheme = htmlElement.getAttribute('data-bs-theme');

                // Force light mode temporarily for high-fidelity capture
                htmlElement.setAttribute('data-theme', 'light');
                htmlElement.setAttribute('data-bs-theme', 'light');

                html2pdf().set(opt).from(invoice).save().then(() => {
                    // Restore themes
                    if (currentDataTheme) htmlElement.setAttribute('data-theme', currentDataTheme);
                    else htmlElement.removeAttribute('data-theme');

                    if (currentBSTheme) htmlElement.setAttribute('data-bs-theme', currentBSTheme);
                    else htmlElement.removeAttribute('data-bs-theme');

                    // Clean up
                    if (document.body.contains(temp)) document.body.removeChild(temp);
                }).catch((error) => {
                    console.error('Error generating PDF:', error);

                    // Restore themes
                    if (currentDataTheme) htmlElement.setAttribute('data-theme', currentDataTheme);
                    else htmlElement.removeAttribute('data-theme');

                    if (currentBSTheme) htmlElement.setAttribute('data-bs-theme', currentBSTheme);
                    else htmlElement.removeAttribute('data-bs-theme');

                    alert('Failed to generate PDF. Please check the console for details and try again.');
                    if (document.body.contains(temp)) document.body.removeChild(temp);
                }).finally(() => {
                    $trigger.data('downloading', false);
                });
            }).catch((error) => {
                console.error('Error preparing PDF:', error);
                alert('Failed to prepare PDF. Please try again.');
                if (document.body.contains(temp)) document.body.removeChild(temp);
                $trigger.data('downloading', false);
            });
        }).fail(function (xhr, status, error) {
            console.error('Error fetching invoice:', error);
            alert('Failed to load invoice data. Please try again.');
            $trigger.data('downloading', false);
        });
    });

    // Card filter
    $(".card-filter").off("click.filter").on("click.filter", function () {
        const $this = $(this);
        const tableSelector = $this.data("table");
        const status = $this.data("status");

        $this.closest(".row").find(".card-filter").removeClass("active");
        $this.addClass("active");

        if ($.fn.DataTable && tableSelector) {
            const table = $(tableSelector).DataTable();
            if (status) {
                table.column(5).search(status, true, false).draw();
            } else {
                table.column(5).search("").draw();
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
        displayFiles.forEach(file => {
            const size = Math.round(file.size / 1024);
            $list.append(`
                <li class="list-group-item d-flex justify-content-between align-items-center file-list-item">
                    <span class="file-name-wrapper" title="${file.name}">${file.name}</span>
                    <span class="badge bg-secondary rounded-pill ms-2 flex-shrink-0">${size} KB</span>
                </li>
            `);
        });
    });
}

document.addEventListener("turbo:load", initInvoicePage);
document.addEventListener("DOMContentLoaded", initInvoicePage);

// Init immediately to catch late-loading scripts
initInvoicePage();
