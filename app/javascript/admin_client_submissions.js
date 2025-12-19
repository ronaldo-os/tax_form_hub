function initSubmissionTables() {
    // Check if we are on the admin or user submissions page
    if (!window.location.pathname.match(/(\/admin\/tax_submissions|\/tax_submissions)/)) {
        return;
    }

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

    // Unbind previously attached events to prevent duplication on reload
    $('button[data-bs-toggle="tab"], a[data-bs-toggle="tab"]').off('shown.bs.tab.dt').on('shown.bs.tab.dt', function () {
        submissionTables.forEach(function (table) {
            table.columns.adjust().responsive.recalc();
        });
    });


    $('.auto-submit').off('change.auto-submit').on('change.auto-submit', function () {
        $(this).closest('form').submit();
    });

    const params = new URLSearchParams(window.location.search);
    const submissionId = params.get("open_submission");

    if (submissionId) {
        const modalElement = document.getElementById("submissionModal");
        if (modalElement) {
            const modal = new bootstrap.Modal(modalElement);
            modal.show();

            // Determine if we should use the admin route or the user route
            const fetchUrl = window.location.pathname.includes("/admin")
                ? "/admin/tax_submissions/" + submissionId
                : "/tax_submissions/" + submissionId;

            $.ajax({
                url: fetchUrl,
                dataType: "script",
                headers: { Accept: "text/javascript" }
            });
        }
    }
}

// Bind to turbo:load for navigation support
// Bind to turbo:load for navigation support
document.addEventListener("turbo:load", initSubmissionTables);

// Also run on DOMContentLoaded just in case turbo isn't controlling the initial load or for fallback
document.addEventListener("DOMContentLoaded", initSubmissionTables);

// Run immediately if the script is loaded after the event has already fired (e.g. via Turbo navigation injection)
initSubmissionTables();
