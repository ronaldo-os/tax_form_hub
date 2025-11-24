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
                    destroy: true,
                    language: {
                        search: "_INPUT_",
                        searchPlaceholder: "Search submissions...",
                        lengthMenu: "Show _MENU_ entries",
                    },
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
