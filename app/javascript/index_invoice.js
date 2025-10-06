if (window.location.pathname.includes("/invoices")) {
    $(document).ready(function () {
        $('#sales-table').DataTable();
        $('#purchases-table').DataTable();
        $('#sales-archived-table').DataTable();
        $('#purchases-archived-table').DataTable();

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

        $(".card-filter").on("click", function (e) {
            e.stopPropagation(); // prevent triggering parent card clicks

            const card = $(this).closest(".card");
            const tableId = card.data("table");
            const status  = card.data("status");
            const table   = $(tableId).DataTable();

            if (status) {
            table.column(4).search("^" + status + "$", true, false).draw();
            } else {
            table.column(4).search("").draw();
            }

            // optional: highlight active filter icon
            $(".card-filter").removeClass("text-primary");
            $(this).addClass("text-primary");
        });


    });
}
