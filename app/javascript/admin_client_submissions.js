function fixEmptyRowColspan(tableApi) {
    if (!tableApi) return;
    const $table = $(tableApi.table().node());
    const totalCols = $table.find('thead tr:first-child th').length || tableApi.columns().count();
    if (totalCols) {
        $table.find('tbody td.dataTables_empty').attr('colspan', totalCols);
    }
}

function initSubmissionTables() {
    // Check if we are on the admin or user submissions page
    if (!window.location.pathname.match(/(\/admin\/tax_submissions|\/tax_submissions)/)) {
        return;
    }

    const submissionTables = [];

    ['#taxSubmissionsTableActive', '#taxSubmissionsTableArchived'].forEach(function (selector) {
        if ($(selector).length) {
            if ($.fn.DataTable.isDataTable(selector)) {
                const table = $(selector).DataTable();
                submissionTables.push(table);
                return;
            }

            const table = $(selector).DataTable({
                responsive: true,
                paging: true,
                searching: true,
                info: true,
                lengthChange: true,
                pageLength: 10,
                stateSave: true,
                language: {
                    search: "_INPUT_",
                    searchPlaceholder: "Search submissions...",
                    lengthMenu: "_MENU_",
                    info: "Showing _START_-_END_ of _TOTAL_ submissions",
                    infoEmpty: "Showing 0-0 of 0 submissions",
                    paginate: {
                        previous: '<i class="fa-solid fa-chevron-left"></i>',
                        next: '<i class="fa-solid fa-chevron-right"></i>'
                    }
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

                    // Setup filter bar container around dataTables_length
                    const $lengthDiv = $container.find('div.dataTables_length');
                    $lengthDiv.addClass('custom-filter-bar d-flex flex-wrap align-items-center gap-2');

                    // Find column indices by header text
                    const headers = api.columns().header().toArray();
                    const companyColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('company'));
                    const statusColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('status'));

                    // Create Company Filter Select if company column exists
                    if (companyColIdx !== -1 && !$container.find('.custom-company-filter').length) {
                        const $companySelect = $('<select class="form-select form-select-sm custom-company-filter"><option value="">All Companies</option></select>');

                        const companySet = new Set();
                        api.column(companyColIdx).data().each(function (d) {
                            const cleanText = $('<div>').html(d).text().trim();
                            if (cleanText && cleanText !== 'N/A') {
                                companySet.add(cleanText);
                            }
                        });

                        Array.from(companySet).sort().forEach(function (comp) {
                            $companySelect.append(`<option value="${comp}">${comp}</option>`);
                        });

                        $companySelect.on('change', function () {
                            const val = $(this).val();
                            if (val) {
                                api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(val) + '$', true, false).draw();
                            } else {
                                api.column(companyColIdx).search('').draw();
                            }
                        });

                        $lengthDiv.append($companySelect);
                    }

                    // Create Status Filter Select if status column exists
                    if (statusColIdx !== -1 && !$container.find('.custom-status-filter').length) {
                        const $statusSelect = $(`
                            <select class="form-select form-select-sm custom-status-filter">
                                <option value="">All Statuses</option>
                                <option value="Pending">Pending</option>
                                <option value="Processed">Processed</option>
                                <option value="Reviewed">Reviewed</option>
                                <option value="Processed & Reviewed">Processed & Reviewed</option>
                            </select>
                        `);

                        $statusSelect.on('change', function () {
                            const val = $(this).val();
                            if (val) {
                                api.column(statusColIdx).search($.fn.dataTable.util.escapeRegex(val), true, false).draw();
                            } else {
                                api.column(statusColIdx).search('').draw();
                            }
                        });

                        $lengthDiv.append($statusSelect);
                    }
                },
                drawCallback: function () {
                    const api = this.api();
                    fixEmptyRowColspan(api);
                }
            });

            $(table.table().node()).on('draw.dt responsive-resize.dt', function () {
                fixEmptyRowColspan(table);
            });

            submissionTables.push(table);
        }
    });

    // Tab persistence and table adjustment
    $('button[data-bs-toggle="tab"]').off('shown.bs.tab').on('shown.bs.tab', function (e) {
        sessionStorage.setItem('activeIncomingSubmissionsTab', $(e.target).attr('id'));
        submissionTables.forEach(function (table) {
            table.columns.adjust().responsive.recalc();
            fixEmptyRowColspan(table);
            setTimeout(function() {
                fixEmptyRowColspan(table);
            }, 50);
        });
    });

    const activeTabId = sessionStorage.getItem('activeIncomingSubmissionsTab');
    if (activeTabId && document.getElementById(activeTabId)) {
        const tabTrigger = bootstrap.Tab.getOrCreateInstance(document.getElementById(activeTabId));
        tabTrigger.show();
    }


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
