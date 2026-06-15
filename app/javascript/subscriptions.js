function initSubscriptionsPage() {
    if (!window.location.pathname.includes("/subscriptions")) return;

    if (typeof $ === 'undefined' || !$.fn.DataTable) {
        console.warn("DataTables not loaded yet, deferring initialization.");
        setTimeout(initSubscriptionsPage, 100);
        return;
    }

    $('.subscription-table').each(function() {
        if (!$.fn.DataTable.isDataTable(this)) {
            $(this).DataTable({
                responsive: true,
                autoWidth: false,
                destroy: true,
                order: [[4, 'asc']], // Order by Next Invoice column
                columnDefs: [
                    { orderable: false, targets: [6] } // Disable ordering on Actions column
                ],
                language: {
                    search: "Search subscriptions:"
                },
                initComplete: function () {
                    const api = this.api();
                    const $container = $(api.table().container());

                    // Optionally remove "Show _ entries" label if desired, but keep it standard
                    // We'll leave the length menu alone for subscriptions
                }
            });
        }
    });
}

document.addEventListener("turbo:load", initSubscriptionsPage);
document.addEventListener("DOMContentLoaded", initSubscriptionsPage);

// Init immediately to catch late-loading scripts
initSubscriptionsPage();
