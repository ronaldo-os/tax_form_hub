if (window.location.pathname.includes("/invoices")) {
    $(document).ready(function () {
        // Render mini charts for invoice trends
        function renderMiniCharts(prefix, trends, color) {
            $.each(trends, function (status, data) {
                const $canvas = $(`#${prefix}-${status}`);
                if (!$canvas.length) return;

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
        const saleTrendsData = $('#invoiceTabsContent').data('sale-trends');
        const purchaseTrendsData = $('#invoiceTabsContent').data('purchase-trends');

        if (saleTrendsData && purchaseTrendsData) {
            renderMiniCharts("chart-sale", saleTrendsData, "#00aeff");
            renderMiniCharts("chart-purchase", purchaseTrendsData, "#00aeff");
        }

        // Initialize all DataTables
        $('#sales-table, #purchases-table, #sales-archived-table, #purchases-archived-table').DataTable({
            responsive: true,
            autoWidth: false,
            destroy: true,
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

        // Handle tab switch
        $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function () {
            setTimeout(function () {
                $.fn.dataTable
                    .tables({ visible: true, api: true })
                    .columns.adjust()
                    .responsive.recalc();
            }, 200); // short delay ensures proper sizing even for empty tables
        });

        // Optional: adjust on window resize too
        $(window).on('resize', function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        });

        // Index datatable download PDF
        $(document).on('click', '.download-pdf', function () {
            const invoiceId = $(this).data('id');

            $.get(`/invoices/${invoiceId}`, { partial: true }, function (html) {
                const temp = document.createElement('div');
                temp.innerHTML = html;
                // Hide the temp div so it doesn't show on the page during PDF generation
                temp.style.position = 'absolute';
                temp.style.left = '-9999px';
                temp.style.visibility = 'hidden';
                document.body.appendChild(temp);

                let invoice = temp.querySelector("#invoice_card");

                if (!invoice) {
                    alert("Invoice HTML not found");
                    return;
                }

                // Create a clean container to replace the #invoice_card wrapper
                // This effectively removes the parent div with id="invoice_card" and its classes
                const content = document.createElement('div');

                // Move all children from invoice card to the clean container
                while (invoice.firstChild) {
                    content.appendChild(invoice.firstChild);
                }

                // Replace the original invoice card with the clean container in the DOM
                invoice.parentNode.replaceChild(content, invoice);

                // Update the invoice variable to point to the new clean container
                invoice = content;

                // Add page break classes to prevent content from being cut off
                // Add avoid class to table rows to prevent them from being split
                const tableRows = invoice.querySelectorAll('table tr');
                tableRows.forEach(row => {
                    row.style.pageBreakInside = 'avoid';
                    row.style.breakInside = 'avoid';
                });

                // Prevent tables from breaking
                const tables = invoice.querySelectorAll('table');
                tables.forEach(table => {
                    table.style.pageBreakInside = 'auto';
                });

                // Prevent other important elements from breaking
                const cards = invoice.querySelectorAll('.card');
                cards.forEach(card => {
                    card.style.pageBreakInside = 'avoid';
                    card.style.breakInside = 'avoid';
                });

                // Get today's date in YYYY-MM-DD format
                const today = new Date();
                const yyyy = today.getFullYear();
                const mm = String(today.getMonth() + 1).padStart(2, '0'); // months are 0-based
                const dd = String(today.getDate()).padStart(2, '0');
                const dateStr = `${yyyy}-${mm}-${dd}`;

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
                    // Clean up: remove the temporary div from the DOM
                    document.body.removeChild(temp);
                }).catch((error) => {
                    console.error('Error generating PDF:', error);
                    alert('Failed to generate PDF. Please try again.');
                    // Clean up even on error
                    if (document.body.contains(temp)) {
                        document.body.removeChild(temp);
                    }
                });
            }).fail(function (xhr, status, error) {
                console.error('Error fetching invoice:', error);
                alert('Failed to load invoice data. Please try again.');
            });
        });

        $(".card-filter").on("click", function () {
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



    });
}
