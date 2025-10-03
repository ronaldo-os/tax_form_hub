if (window.location.pathname.includes("/admin/tax_submissions")) {
    $(document).ready(function () {
        const submissionTables = [];

        ['#taxSubmissionsTableActive', '#taxSubmissionsTableArchived'].forEach(function (selector) {
        if ($(selector).length) {
            const table = $(selector).DataTable({
            responsive: true,
            paging: true,
            searching: true,
            info: true,
            lengthChange: true,
            pageLength: 10,
            language: {
                search: "_INPUT_",
                searchPlaceholder: "Search submissions...",
                lengthMenu: "Show _MENU_ entries",
            }
            });

            submissionTables.push(table);
        }
        });

        $('button[data-bs-toggle="tab"], a[data-bs-toggle="tab"]').on('shown.bs.tab', function () {
            submissionTables.forEach(function (table) {
                table.columns.adjust().responsive.recalc();
            });
        });


        $('.auto-submit').on('change', function () {
            $(this).closest('form').submit();
        });

        const params = new URLSearchParams(window.location.search);
        const submissionId = params.get("open_submission");

        if (submissionId) {
            const modal = new bootstrap.Modal($("#submissionModal")[0]);
            modal.show();

            $.ajax({
            url: "/admin/tax_submissions/" + submissionId,
            dataType: "script",
            headers: { Accept: "text/javascript" }
            });
        }
        
    });
}
