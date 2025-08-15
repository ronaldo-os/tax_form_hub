if (window.location.pathname.includes("/recurring_invoices")) {
    $('#recurring-items-table').DataTable();

    $(document).ready(function () {
        // Open modal & populate fields
        $(document).on("click", ".edit-btn", function() {
            $("#invoice_id").val($(this).data("invoice-id"));
            $("#line_index").val($(this).data("line-index"));
            $("#mode").val($(this).data("mode"));
            $("#interval").val($(this).data("interval"));
            $("#every").val($(this).data("every"));
            $("#start_date").val($(this).data("start-date"));
            $("#end_date").val($(this).data("end-date"));
            $("#count").val($(this).data("count"));

            $("#editRecurringModal").modal("show");
        });


        // Handle form submission via AJAX
        $("#editRecurringForm").on("submit", function (e) {
            e.preventDefault();

            const invoiceId = $("#invoice_id").val();

            $.ajax({
                url: `/recurring_invoices/${invoiceId}`,
                type: "PATCH",
                data: $(this).serialize(),
                dataType: "json",
                headers: {
                    "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
                },
                success: function (response) {
                    location.reload();
                },
                error: function () {
                    alert("Failed to update recurring item.");
                }
            });
        });

        $(document).on('click', '.disable-btn', function() {
        if (confirm('Disable this recurring item?')) {
            const invoiceId = $(this).data('invoice-id');
            const lineIndex = $(this).data('line-index');

            $.ajax({
            url: `/recurring_invoices/disable`,
            method: 'PATCH',
            data: { invoice_id: invoiceId, line_index: lineIndex },
            success: function() {
                alert('Recurring item disabled.');
                location.reload();
            }
            });
        }
        });

        $(document).on('click', '.delete-btn', function() {
        if (confirm('Delete this recurring item?')) {
            const invoiceId = $(this).data('invoice-id');
            const lineIndex = $(this).data('line-index');

            $.ajax({
            url: `/recurring_invoices/${invoiceId}`,
            method: 'DELETE',
            data: { line_index: lineIndex },
            success: function() {
                alert('Recurring item deleted.');
                location.reload();
            }
            });
        }
        });

    });

}
