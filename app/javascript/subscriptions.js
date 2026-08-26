function initSubscriptionsPage() {
    if (!window.location.pathname.includes("/subscriptions")) return;

    if (typeof $ === 'undefined' || !$.fn.DataTable) {
        console.warn("DataTables not loaded yet, deferring initialization.");
        setTimeout(initSubscriptionsPage, 100);
        return;
    }

    $('.subscription-table').each(function() {
        const tableNode = this;

        if ($.fn.DataTable.isDataTable(tableNode)) {
            const dt = $(tableNode).DataTable();
            dt.destroy();
        }

        // Attach capture-phase listener to stop DataTables Responsive from toggling row collapse when interactive elements are clicked
        if (!tableNode.dataset.responsiveFixAttached) {
            tableNode.addEventListener('click', function(e) {
                if (e.target.closest('a, button, input, select, textarea, .dropdown-toggle, .dropdown-menu')) {
                    e.stopImmediatePropagation();
                }
            }, true); // true = Capture phase execution
            tableNode.dataset.responsiveFixAttached = 'true';
        }

        $(tableNode).DataTable({
            responsive: true,
            autoWidth: false,
            destroy: true,
            order: [[4, 'asc']], // Order by Next Invoice column
            columnDefs: [
                { orderable: false, targets: [6] } // Disable ordering on Actions column
            ],
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
            }
        });
    });

    // Handle top-level tab switch (Sales vs Purchases)
    $('#subscriptionTypeTabs button[data-bs-toggle="tab"]').off('shown.bs.tab.subs').on('shown.bs.tab.subs', function (e) {
        const tabId = $(e.target).attr('id').replace('-tab', '');
        const url = new URL(window.location);
        url.searchParams.set('tab', tabId);
        window.history.replaceState({}, '', url);

        setTimeout(function () {
            $.fn.dataTable
                .tables({ visible: true, api: true })
                .columns.adjust()
                .responsive.recalc();
        }, 150);
    });

    // Also recalculate when inner status tabs are clicked
    $('.subscriptions-page button[data-bs-toggle="tab"]').off('shown.bs.tab.subs_inner').on('shown.bs.tab.subs_inner', function () {
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

// Init immediately to catch late-loading scripts
initSubscriptionsPage();
