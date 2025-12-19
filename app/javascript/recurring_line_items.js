function initRecurringInvoicesPage() {
    if (!window.location.pathname.includes("/recurring_invoices")) return;

    const activeTable = $('#recurring-items-table').DataTable({
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

    const disabledTable = $('#disabled-recurring-items-table').DataTable({
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

    // Open modal & populate fields
    $(document).off("click.edit-btn").on("click.edit-btn", ".edit-btn", function () {
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
    $("#editRecurringForm").off("submit").on("submit", function (e) {
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
            success: function () {
                location.reload();
            },
            error: function (xhr) {
                console.error('Update failed:', xhr.status, xhr.responseText);
                location.reload();
            }
        });
    });

    // Setup CSRF for all AJAX requests
    $.ajaxSetup({
        headers: { "X-CSRF-Token": $("meta[name='csrf-token']").attr("content") }
    });

    // Enable recurring item
    $(document).off('click.enable-btn').on('click.enable-btn', '.enable-btn', function () {
        if (!confirm('Enable this recurring item?')) return;

        const invoiceId = $(this).data('invoice-id');
        const lineIndex = $(this).data('line-index');

        $.ajax({
            url: `/recurring_invoices/enable`,
            method: 'PATCH',
            dataType: 'json',
            data: { invoice_id: invoiceId, line_index: lineIndex },
            success: function () { location.reload(); },
            error: function (xhr) {
                console.error('Enable failed:', xhr.status, xhr.responseText);
                location.reload();
            }
        });
    });

    // Disable recurring item
    $(document).off('click.disable-btn').on('click.disable-btn', '.disable-btn', function () {
        if (!confirm('Disable this recurring item?')) return;

        const invoiceId = $(this).data('invoice-id');
        const lineIndex = $(this).data('line-index');

        $.ajax({
            url: `/recurring_invoices/disable`,
            method: 'PATCH',
            dataType: 'json',
            data: { invoice_id: invoiceId, line_index: lineIndex },
            success: function () { location.reload(); },
            error: function (xhr) {
                console.error('Disable failed:', xhr.status, xhr.responseText);
                location.reload();
            }
        });
    });

    // Delete recurring item
    $(document).off('click.delete-btn').on('click.delete-btn', '.delete-btn', function (e) {
        e.preventDefault();
        if (!confirm('Delete this recurring item?')) return;

        const $row = $(this).closest('tr');
        const invoiceId = $(this).data('invoice-id');
        const lineIndex = $(this).data('line-index');

        $.ajax({
            url: `/recurring_invoices/${invoiceId}`,
            method: 'DELETE',
            dataType: 'json',
            data: { line_index: lineIndex },
            success: function () {
                // Remove from DataTable immediately
                if (activeTable.row($row).length) {
                    activeTable.row($row).remove().draw();
                } else if (disabledTable.row($row).length) {
                    disabledTable.row($row).remove().draw();
                } else {
                    const t = $row.closest('table').DataTable();
                    t.row($row).remove().draw();
                }
                location.reload();
            },
            error: function (xhr) {
                console.error('Delete failed:', xhr.status, xhr.responseText);
                location.reload();
            }
        });
    });

    // Interval change logic
    $('.btn-link').off('change').on('change', function () {
        if ($(this).val() === 'daily') {
            $('#every').val(0).prop('disabled', true);
        } else {
            $('#every').prop('disabled', false);
        }
    });

    $('#interval').trigger('change');
}

document.addEventListener("turbo:load", initRecurringInvoicesPage);
document.addEventListener("DOMContentLoaded", initRecurringInvoicesPage);

// Init immediately to catch late-loading scripts
initRecurringInvoicesPage();
