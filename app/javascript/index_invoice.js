function initInvoicePage() {
    if (!window.location.pathname.includes("/invoices")) return;

    // Render mini charts for invoice trends
    function renderMiniCharts(prefix, trends, color) {
        // Remove existing chart instance if any to avoid canvas reuse issues
        const $canvas = $(`#${prefix}-${status}`);
        // Logic handled by Chart.js generally, but good to be aware. 
        // In this specific existing code, it creates new Chart every time.
        // Ideally we should destroy old charts, but let's stick to the structure refactor first.

        $.each(trends, function (status, data) {
            const $canvas = $(`#${prefix}-${status}`);
            if (!$canvas.length) return;

            // Destroy existing chart if it exists attached to this canvas
            // This is a safety measure for Turbo re-renders if the canvas is preserved
            const existingChart = Chart.getChart($canvas[0]);
            if (existingChart) existingChart.destroy();

            const ctx = $canvas[0].getContext("2d");

            new Chart(ctx, {
                type: "bar",
                data: {
                    labels: data.map(d => d.month),
                    datasets: [{
                        data: data.map(d => d.count),
                        backgroundColor: color,
                        borderRadius: 5,
                        barThickness: 4,
                    }]
                },
                options: {
                    plugins: { legend: { display: false }, tooltip: { enabled: false } },
                    scales: {
                        x: { display: false },
                        y: { display: false }
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

    // Initialize all DataTables
    $('#sales-table, #purchases-table, #sales-archived-table, #purchases-archived-table').DataTable({
        responsive: true,
        autoWidth: false,
        destroy: true, // Important for Turbo
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

    // PDF Download
    $(document).off('click.pdf-download').on('click.pdf-download', '.download-pdf', function () {
        const invoiceId = $(this).data('id');

        $.get(`/invoices/${invoiceId}`, { partial: true }, function (html) {
            const temp = document.createElement('div');
            temp.innerHTML = html;
            temp.style.position = 'absolute';
            temp.style.left = '-9999px';
            temp.style.visibility = 'hidden';
            document.body.appendChild(temp);

            let invoice = temp.querySelector("#invoice_card");

            if (!invoice) {
                alert("Invoice HTML not found");
                if (document.body.contains(temp)) document.body.removeChild(temp);
                return;
            }

            const content = document.createElement('div');
            while (invoice.firstChild) {
                content.appendChild(invoice.firstChild);
            }
            invoice.parentNode.replaceChild(content, invoice);
            invoice = content;

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

            const today = new Date();
            const dateStr = today.toISOString().split('T')[0];

            const opt = {
                margin: [10, 10, 10, 10],
                filename: `${dateStr}-invoice-${invoiceId}.pdf`,
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: {
                    scale: 2,
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
                    mode: ['avoid-all', 'css', 'legacy'],
                    before: '.page-break-before',
                    after: '.page-break-after',
                    avoid: ['tr', '.card', 'table']
                }
            };

            html2pdf().set(opt).from(invoice).save().then(() => {
                if (document.body.contains(temp)) document.body.removeChild(temp);
            }).catch((error) => {
                console.error('Error generating PDF:', error);
                alert('Failed to generate PDF. Please try again.');
                if (document.body.contains(temp)) document.body.removeChild(temp);
            });
        }).fail(function (xhr, status, error) {
            console.error('Error fetching invoice:', error);
            alert('Failed to load invoice data. Please try again.');
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
                table.column(4).search(status, true, false).draw();
            } else {
                table.column(4).search("").draw();
            }
        }
    });
}

document.addEventListener("turbo:load", initInvoicePage);
document.addEventListener("DOMContentLoaded", initInvoicePage);

// Init immediately to catch late-loading scripts
initInvoicePage();
