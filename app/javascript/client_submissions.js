if (window.location.pathname.includes("")) {
    $(document).ready(function () {
        const tables = [];

        $('.submissionsTable').each(function () {
        const table = $(this).DataTable({
            responsive: true,
            paging: true,
            searching: true,
            ordering: true,
            order: [[5, 'desc']],
            pageLength: 10,
            lengthChange: true,
            language: {
            search: "_INPUT_",
            searchPlaceholder: "Search submissions...",
            lengthMenu: "Show _MENU_ entries",
            }
        });

        tables.push(table);
        });

        $('a[data-bs-toggle="tab"]').on('shown.bs.tab', function () {
            tables.forEach(function (table) {
                table.columns.adjust().responsive.recalc();
            });
        });

    });
}
