import { exportSubmissionsToCsv } from './tax_submissions_export';
import { setupTaxSubmissionsBulkActions } from './tax_submissions_bulk';
import { getInitialTableState, updateUrlParams, bindSearchInputSync, bindPaginationSync, resolveSortOrder, bindOrderSync } from './table_url_sync';

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

    const initial = getInitialTableState();

    // Tab restoration based on URL parameter or sessionStorage fallback
    if (initial.tab === 'archived') {
        const archivedTab = document.getElementById('archived-tab');
        if (archivedTab && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
            bootstrap.Tab.getOrCreateInstance(archivedTab).show();
        }
    } else if (initial.tab === 'active') {
        const activeTab = document.getElementById('active-tab');
        if (activeTab && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
            bootstrap.Tab.getOrCreateInstance(activeTab).show();
        }
    } else {
        const activeTabId = sessionStorage.getItem('activeIncomingSubmissionsTab');
        if (activeTabId && document.getElementById(activeTabId)) {
            const tabTrigger = bootstrap.Tab.getOrCreateInstance(document.getElementById(activeTabId));
            tabTrigger.show();
        }
    }

    const submissionTables = [];

    ['#taxSubmissionsTableActive', '#taxSubmissionsTableArchived'].forEach(function (selector) {
        if ($(selector).length) {
            if ($.fn.DataTable.isDataTable(selector)) {
                const table = $(selector).DataTable();
                submissionTables.push(table);
                setupTaxSubmissionsBulkActions(table, selector.replace('#', ''));
                return;
            }

            const defaultOrder = [[9, 'desc']];
            const resolvedOrder = resolveSortOrder($(selector), initial.sort, initial.dir, defaultOrder);

            const table = $(selector).DataTable({
                responsive: true,
                paging: true,
                searching: true,
                info: true,
                lengthChange: true,
                pageLength: 10,
                displayStart: initial.page > 1 ? (initial.page - 1) * 10 : 0,
                order: resolvedOrder,
                columnDefs: [
                    { orderable: false, targets: [0, -1] }
                ],
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

                    let needsRedraw = false;

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
                            updateUrlParams({ company: val || null }, { clearPage: true });
                            if (val) {
                                api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(val) + '$', true, false).draw();
                            } else {
                                api.column(companyColIdx).search('').draw();
                            }
                        });

                        $lengthDiv.append($companySelect);

                        if (initial.company) {
                            $companySelect.val(initial.company);
                            if ($companySelect.val() === initial.company) {
                                api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(initial.company) + '$', true, false);
                                needsRedraw = true;
                            }
                        }
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
                            updateUrlParams({ status: val || null }, { clearPage: true });
                            if (val) {
                                api.column(statusColIdx).search($.fn.dataTable.util.escapeRegex(val), true, false).draw();
                            } else {
                                api.column(statusColIdx).search('').draw();
                            }
                        });

                        $lengthDiv.append($statusSelect);

                        if (initial.status) {
                            $statusSelect.val(initial.status);
                            if ($statusSelect.val()) {
                                api.column(statusColIdx).search($.fn.dataTable.util.escapeRegex(initial.status), true, false);
                                needsRedraw = true;
                            }
                        }
                    }

                    // Append Export CSV button to custom filter bar
                    if (!$container.find('.custom-export-csv-btn').length) {
                        const $exportBtn = $(`
                            <button type="button" class="btn btn-outline-secondary btn-sm custom-export-csv-btn d-inline-flex align-items-center gap-1.5" title="Export filtered submissions to CSV">
                                <i class="fa-solid fa-file-csv text-success"></i>
                                <span>Export CSV</span>
                            </button>
                        `);

                        $exportBtn.on('click', function (e) {
                            e.preventDefault();
                            const isArchived = selector.includes('Archived');
                            exportSubmissionsToCsv(api, isArchived ? 'tax_submissions_incoming_archived' : 'tax_submissions_incoming_active', true);
                        });

                        $lengthDiv.append($exportBtn);
                    }

                    // Search input synchronization
                    const $searchInput = $container.find('div.dataTables_filter input');
                    if (initial.search) {
                        $searchInput.val(initial.search);
                        api.search(initial.search);
                        needsRedraw = true;
                    }
                    bindSearchInputSync($searchInput);
                    bindPaginationSync(api);
                    bindOrderSync(api, { defaultOrder: defaultOrder });

                    if (needsRedraw) {
                        api.draw(false);
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
            setupTaxSubmissionsBulkActions(table, selector.replace('#', ''));
        }
    });

    // Tab persistence and table adjustment
    $('button[data-bs-toggle="tab"]').off('shown.bs.tab').on('shown.bs.tab', function (e) {
        const targetId = $(e.target).attr('id') || '';
        const isArchived = targetId.includes('archived');
        sessionStorage.setItem('activeIncomingSubmissionsTab', targetId);
        updateUrlParams({ tab: isArchived ? 'archived' : 'active' });
        submissionTables.forEach(function (table) {
            table.columns.adjust().responsive.recalc();
            fixEmptyRowColspan(table);
            setTimeout(function() {
                fixEmptyRowColspan(table);
            }, 50);
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

    // Global Header Export CSV Button Handler for Incoming Submissions
    $(document).off('click', '#exportIncomingSubmissionsBtn').on('click', '#exportIncomingSubmissionsBtn', function (e) {
        e.preventDefault();
        const $activePane = $('#submissionTabsContent > .tab-pane.active, #submissionTabsContent > .tab-pane.show.active, #submissionTabsContent .tab-pane.active').first();
        const $activeTable = $activePane.find('table.dataTable:visible, table:visible, table').first();
        if ($activeTable.length && $.fn.DataTable.isDataTable($activeTable[0])) {
            const api = $activeTable.DataTable();
            const isArchived = $activePane.attr('id') === 'archivedSubmissions';
            exportSubmissionsToCsv(api, isArchived ? 'tax_submissions_incoming_archived' : 'tax_submissions_incoming_active', true);
        }
    });
}

document.addEventListener("turbo:load", initSubmissionTables);
document.addEventListener("DOMContentLoaded", initSubmissionTables);
window.addEventListener("popstate", function () {
    if (window.location.pathname.match(/(\/admin\/tax_submissions|\/tax_submissions)/)) {
        initSubmissionTables();
    }
});

// Run immediately if the script is loaded after the event has already fired (e.g. via Turbo navigation injection)
initSubmissionTables();
