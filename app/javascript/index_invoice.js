if (window.location.pathname.includes("/invoices")) {
    $(document).ready(function () {
        // Initialize all DataTables
        $('#sales-table, #purchases-table, #sales-archived-table, #purchases-archived-table').DataTable({
            responsive: true,
            autoWidth: false
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

            $.get(`/invoices/${invoiceId}`, { partial: true }, function(html) {
                const temp = document.createElement('div');
                temp.innerHTML = html;
                document.body.appendChild(temp);

                const invoice = temp.querySelector("#invoice_card");

                if (!invoice) {
                alert("Invoice HTML not found");
                return;
                }

                // Get today's date in YYYY-MM-DD format
                const today = new Date();
                const yyyy = today.getFullYear();
                const mm = String(today.getMonth() + 1).padStart(2, '0'); // months are 0-based
                const dd = String(today.getDate()).padStart(2, '0');
                const dateStr = `${yyyy}-${mm}-${dd}`;

                const opt = {
                margin: [8, 8, 8, 8],
                filename: `${dateStr}-invoice-${invoiceId}.pdf`,
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: { scale: 2, useCORS: true },
                jsPDF: { unit: 'pt', format: 'a4', orientation: 'portrait' }
                };

                html2pdf().set(opt).from(invoice).save().then(() => {
                temp.remove();
                });
            }, 'html');
        });

        $(".card-filter").on("click", function() {
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
