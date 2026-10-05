import { getInitialTableState, updateUrlParams, bindSearchInputSync, bindPaginationSync, resolveSortOrder, bindOrderSync } from './table_url_sync';

function fixEmptyRowColspan(api) {
    const table = api.table ? api.table().node() : api;
    const $emptyCell = $(table).find('td.dataTables_empty');
    if ($emptyCell.length) {
        const totalCols = $(table).find('thead tr:first-child th').length;
        if (totalCols > 0) {
            $emptyCell.attr('colspan', totalCols);
        }
    }
}

function setupSubscriptionsBulkActions(tableApi, tableId) {
    if (!tableApi) return;

    const tableNode = tableApi.table().node();
    const $table = $(tableNode);
    const effectiveTableId = tableId || $table.attr('id');
    if (!effectiveTableId) return;

    const bulkBar = document.getElementById(`bulk_action_bar_${effectiveTableId}`);
    const bulkForm = document.getElementById(`bulk_form_${effectiveTableId}`);
    const headerCheckbox = document.getElementById(`header_checkbox_${effectiveTableId}`);
    const masterBulkCheckbox = document.getElementById(`master_bulk_${effectiveTableId}`);

    if (!bulkBar || !bulkForm) return;

    const selectedIds = new Set();

    function updateBulkBar() {
        const count = selectedIds.size;
        const countSpan = bulkBar.querySelector('.selected-count');
        if (countSpan) {
            countSpan.textContent = count.toString();
        }

        if (count > 0) {
            bulkBar.classList.remove('d-none');
        } else {
            bulkBar.classList.add('d-none');
        }

        // Synchronize checkboxes in current DOM page with selectedIds
        const allRowNodes = tableApi.rows().nodes();
        $(allRowNodes).each(function () {
            const $cb = $(this).find('.subscription-row-checkbox');
            if ($cb.length) {
                const subId = $cb.val();
                const isSelected = selectedIds.has(subId);
                $cb.prop('checked', isSelected);
                $(this).toggleClass('row-selected table-active', isSelected);
            }
        });

        // Determine if all visible (under current search/filter) are selected
        const activeRows = tableApi.rows({ search: 'applied' }).nodes();
        let activeTotal = 0;
        let activeSelected = 0;
        $(activeRows).each(function () {
            const $cb = $(this).find('.subscription-row-checkbox');
            if ($cb.length) {
                activeTotal++;
                if (selectedIds.has($cb.val())) {
                    activeSelected++;
                }
            }
        });

        const isAllSelected = activeTotal > 0 && activeSelected === activeTotal;
        const isIndeterminate = activeSelected > 0 && activeSelected < activeTotal;

        if (headerCheckbox) {
            headerCheckbox.checked = isAllSelected;
            headerCheckbox.indeterminate = isIndeterminate;
        }

        if (masterBulkCheckbox) {
            masterBulkCheckbox.checked = isAllSelected;
            masterBulkCheckbox.indeterminate = isIndeterminate;
        }
    }

    function toggleAllVisible(isChecked) {
        const activeRows = tableApi.rows({ search: 'applied' }).nodes();
        $(activeRows).each(function () {
            const $cb = $(this).find('.subscription-row-checkbox');
            if ($cb.length) {
                const subId = $cb.val();
                if (isChecked) {
                    selectedIds.add(subId);
                } else {
                    selectedIds.delete(subId);
                }
            }
        });
        updateBulkBar();
    }

    // Header checkbox toggle
    if (headerCheckbox && !headerCheckbox.dataset.bulkBound) {
        headerCheckbox.dataset.bulkBound = 'true';
        headerCheckbox.addEventListener('change', function () {
            toggleAllVisible(this.checked);
        });
    }

    // Master checkbox in bulk bar toggle
    if (masterBulkCheckbox && !masterBulkCheckbox.dataset.bulkBound) {
        masterBulkCheckbox.dataset.bulkBound = 'true';
        masterBulkCheckbox.addEventListener('change', function () {
            toggleAllVisible(this.checked);
        });
    }

    // Row checkbox change (delegated to table node for dynamic / paginated rows)
    $table.off('change.subscriptionCheckbox', '.subscription-row-checkbox').on('change.subscriptionCheckbox', '.subscription-row-checkbox', function () {
        const subId = this.value;
        if (this.checked) {
            selectedIds.add(subId);
        } else {
            selectedIds.delete(subId);
        }
        updateBulkBar();
    });

    // Row click toggle: clicking row (outside buttons/links/dropdowns/inputs) toggles checkbox
    $table.off('click.subscriptionRow', 'tbody tr').on('click.subscriptionRow', 'tbody tr', function (e) {
        if ($(e.target).closest('a, button, input, select, textarea, .dropdown, label').length) return;
        const $cb = $(this).find('.subscription-row-checkbox');
        if ($cb.length) {
            $cb.prop('checked', !$cb.prop('checked')).trigger('change');
        }
    });

    // Clear selection button
    const clearBtn = bulkBar.querySelector('.clear-selection-btn');
    if (clearBtn && !clearBtn.dataset.bulkBound) {
        clearBtn.dataset.bulkBound = 'true';
        clearBtn.addEventListener('click', function (e) {
            e.preventDefault();
            selectedIds.clear();
            updateBulkBar();
        });
    }

    // Form submission: inject hidden inputs for all selected subscriptions across all pages
    if (bulkForm && !bulkForm.dataset.bulkFormBound) {
        bulkForm.dataset.bulkFormBound = 'true';
        bulkForm.addEventListener('submit', function (e) {
            // Remove previously appended hidden inputs
            bulkForm.querySelectorAll('input[name="subscription_ids[]"]').forEach((el) => el.remove());

            if (selectedIds.size === 0) {
                e.preventDefault();
                return;
            }

            selectedIds.forEach((subId) => {
                const hiddenInput = document.createElement('input');
                hiddenInput.setAttribute('type', 'hidden');
                hiddenInput.setAttribute('name', 'subscription_ids[]');
                hiddenInput.setAttribute('value', subId.toString());
                bulkForm.appendChild(hiddenInput);
            });
        });
    }

    // When DataTable is redrawn (page change, search, sort), re-synchronize state
    tableApi.off('draw.subsBulk').on('draw.subsBulk', function () {
        updateBulkBar();
    });

    // Initial state check
    updateBulkBar();
}

function initSubscriptionsPage() {
    if (!window.location.pathname.includes("/subscriptions")) return;

    if (typeof $ === 'undefined' || !$.fn.DataTable) {
        console.warn("DataTables not loaded yet, deferring initialization.");
        setTimeout(initSubscriptionsPage, 100);
        return;
    }

    const initial = getInitialTableState();

    // Restore top-level tab (sales vs purchases)
    if (initial.tab) {
        const topTabBtn = document.getElementById(`${initial.tab}-tab`);
        if (topTabBtn && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
            bootstrap.Tab.getOrCreateInstance(topTabBtn).show();
        }
    }

    // Restore inner status tab (active, finished, cancelled)
    const statusParam = initial.status || initial.subtab;
    if (statusParam) {
        const currentTopTab = (initial.tab && ['sales', 'purchases'].includes(initial.tab)) ? initial.tab : 'sales';
        const innerTabId = `${currentTopTab}-${statusParam}-tab`;
        const innerTabBtn = document.getElementById(innerTabId);
        if (innerTabBtn && typeof bootstrap !== 'undefined' && bootstrap.Tab) {
            bootstrap.Tab.getOrCreateInstance(innerTabBtn).show();
        }
    }

    $('.subscription-table').each(function() {
        const tableNode = this;
        const tableId = $(tableNode).attr('id');

        if ($.fn.DataTable.isDataTable(tableNode)) {
            const dt = $(tableNode).DataTable();
            dt.destroy();
        }

        // Attach capture-phase listener to stop DataTables Responsive from toggling row collapse when interactive elements are clicked
        if (!tableNode.dataset.responsiveFixAttached) {
            tableNode.addEventListener('click', function(e) {
                if (e.target.closest('a, button, input, select, textarea, .dropdown-toggle, .dropdown-menu, label')) {
                    e.stopImmediatePropagation();
                }
            }, true); // true = Capture phase execution
            tableNode.dataset.responsiveFixAttached = 'true';
        }

        const hasCheckboxCol = $(tableNode).find('thead th input.table-header-checkbox').length > 0;
        
        // Find column index for Next Invoice
        const headers = $(tableNode).find('thead tr:first-child th').toArray();
        let nextInvoiceColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('next invoice'));
        if (nextInvoiceColIdx === -1) {
            nextInvoiceColIdx = hasCheckboxCol ? 5 : 4;
        }

        const columnDefs = hasCheckboxCol 
            ? [{ orderable: false, targets: [0, -1] }] 
            : [{ orderable: false, targets: [-1] }];

        const defaultOrder = [[nextInvoiceColIdx, 'asc']];
        const resolvedOrder = resolveSortOrder($(tableNode), initial.sort, initial.dir, defaultOrder);

        const tableApi = $(tableNode).DataTable({
            responsive: true,
            autoWidth: false,
            destroy: true,
            pageLength: 25,
            displayStart: initial.page > 1 ? (initial.page - 1) * 25 : 0,
            lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
            order: resolvedOrder,
            columnDefs: columnDefs,
            language: {
                search: "",
                searchPlaceholder: "Search subscriptions...",
                paginate: {
                    previous: '<i class="fa-solid fa-chevron-left"></i>',
                    next: '<i class="fa-solid fa-chevron-right"></i>'
                }
            },
            initComplete: function () {
                const api = this.api();
                const $container = $(api.table().container());

                // Remove "Show _ entries" text nodes from length control
                $container.find('div.dataTables_length label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();

                // Remove "Search:" text nodes from filter control
                $container.find('div.dataTables_filter label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();

                // Setup filter bar container around dataTables_length (only per-page dropdown filter)
                const $lengthDiv = $container.find('div.dataTables_length');
                $lengthDiv.addClass('custom-filter-bar d-flex flex-wrap align-items-center gap-2');

                const $searchInput = $container.find('div.dataTables_filter input');
                if (initial.search) {
                    $searchInput.val(initial.search);
                    api.search(initial.search).draw(false);
                }
                bindSearchInputSync($searchInput);
                bindPaginationSync(api);
                bindOrderSync(api, { defaultOrder: defaultOrder });

                if (hasCheckboxCol && tableId) {
                    setupSubscriptionsBulkActions(api, tableId);
                }
            },
            drawCallback: function () {
                fixEmptyRowColspan(this.api());
            }
        });
    });

    // Fix empty row colspan on resize
    $('.subscription-table').on('draw.dt responsive-resize.dt', function () {
        fixEmptyRowColspan(this);
    });

    // Generated Invoices Table on Subscriptions Show page
    $('.generated-invoices-table').each(function() {
        const tableNode = this;
        if ($.fn.DataTable.isDataTable(tableNode)) {
            $(tableNode).DataTable().destroy();
        }

        const rowCount = $(tableNode).find('tbody tr').length;
        if (rowCount > 0) {
            $(tableNode).DataTable({
                responsive: true,
                autoWidth: false,
                destroy: true,
                pageLength: 25,
                lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
                order: [[1, 'desc']], // Order by Issue Date
                columnDefs: [
                    { orderable: false, targets: [4] } // Disable ordering on Action column
                ],
                language: {
                    search: "_INPUT_",
                    searchPlaceholder: "Search invoices...",
                    lengthMenu: "_MENU_",
                    info: "Showing _START_-_END_ of _TOTAL_ invoices",
                    infoEmpty: "Showing 0-0 of 0 invoices",
                    paginate: {
                        previous: '<i class="fa-solid fa-chevron-left"></i>',
                        next: '<i class="fa-solid fa-chevron-right"></i>'
                    }
                },
                initComplete: function () {
                    const api = this.api();
                    const $container = $(api.table().container());

                    $container.find('div.dataTables_length label').contents().filter(function () {
                        return this.nodeType === 3;
                    }).remove();

                    $container.find('div.dataTables_filter label').contents().filter(function () {
                        return this.nodeType === 3;
                    }).remove();
                }
            });
        }
    });

    // Handle top-level tab switch (Sales vs Purchases)
    $('#subscriptionTypeTabs button[data-bs-toggle="tab"]').off('shown.bs.tab.subs').on('shown.bs.tab.subs', function (e) {
        const tabId = $(e.target).attr('id').replace('-tab', '');
        updateUrlParams({ tab: tabId });

        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 150);
    });

    // Also recalculate when inner status tabs are clicked and sync status param
    $('.subscriptions-page button[data-bs-toggle="tab"]').off('shown.bs.tab.subs_inner').on('shown.bs.tab.subs_inner', function (e) {
        const tabBtnId = $(e.target).attr('id') || '';
        let status = null;
        if (tabBtnId.includes('-active-tab')) status = 'active';
        else if (tabBtnId.includes('-finished-tab')) status = 'finished';
        else if (tabBtnId.includes('-cancelled-tab')) status = 'cancelled';

        if (status) {
            updateUrlParams({ status: status === 'active' ? null : status }, { clearPage: true });
        }

        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 100);
    });
}

document.addEventListener("turbo:load", initSubscriptionsPage);
document.addEventListener("DOMContentLoaded", initSubscriptionsPage);
window.addEventListener("popstate", function () {
    if (window.location.pathname.includes("/subscriptions")) {
        initSubscriptionsPage();
    }
});

// Init immediately to catch late-loading scripts
initSubscriptionsPage();
