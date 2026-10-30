import { getInitialTableState, updateUrlParams, getUrlParam, activateTabElement, bindSearchInputSync, bindPaginationSync, resolveSortOrder, bindOrderSync } from './table_url_sync';

const VALID_TOP_TABS = ['sales', 'purchases'];
const VALID_SUB_STATUSES = ['active', 'finished', 'cancelled'];

function getStoredSubStatus(topTab, isPriceAdjustment) {
    try {
        const key = `subscriptions_${topTab}_${isPriceAdjustment ? 'pa_status' : 'status'}`;
        const val = sessionStorage.getItem(key);
        return VALID_SUB_STATUSES.includes(val) ? val : null;
    } catch (e) {
        return null;
    }
}

function setStoredSubStatus(topTab, isPriceAdjustment, status) {
    if (!VALID_TOP_TABS.includes(topTab) || !VALID_SUB_STATUSES.includes(status)) return;
    try {
        const key = `subscriptions_${topTab}_${isPriceAdjustment ? 'pa_status' : 'status'}`;
        sessionStorage.setItem(key, status);
    } catch (e) {
        // Ignore storage errors
    }
}

function parseSubStatusFromTabId(tabBtnId) {
    if (!tabBtnId) return null;
    if (tabBtnId.includes('-active-')) return 'active';
    if (tabBtnId.includes('-finished-')) return 'finished';
    if (tabBtnId.includes('-cancelled-')) return 'cancelled';
    return null;
}

function getActivePaneSubStatuses(topTab) {
    const activeSubBtn = document.querySelector(`#${topTab}SubscriptionTabs button.active, #${topTab}SubscriptionTabs button[aria-selected="true"]`);
    const activePaBtn = document.querySelector(`#${topTab}PriceAdjustmentTabs button.active, #${topTab}PriceAdjustmentTabs button[aria-selected="true"]`);

    const subStatus = (activeSubBtn && parseSubStatusFromTabId(activeSubBtn.id)) || getStoredSubStatus(topTab, false) || 'active';
    const paStatus = (activePaBtn && parseSubStatusFromTabId(activePaBtn.id)) || getStoredSubStatus(topTab, true) || 'active';

    return { subStatus, paStatus };
}

function syncSubscriptionsDropdownLinks(topTab) {
    const dropdownMenu = document.querySelector('#createDocumentDropdown + .dropdown-menu');
    if (!dropdownMenu) return;
    const invoiceTab = topTab === 'purchases' ? 'purchase-invoices' : 'sales-invoices';
    dropdownMenu.querySelectorAll('a.dropdown-item').forEach((link) => {
        try {
            const url = new URL(link.href, window.location.origin);
            url.searchParams.set('tab', invoiceTab);
            link.href = url.pathname + url.search;
        } catch (err) {
            // Ignore malformed URLs
        }
    });
}

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

/**
 * Parses the comma-separated allowed bulk actions from a row checkbox,
 * with a fallback to inspect the row's Actions dropdown if not specified on the dataset.
 *
 * @param {HTMLElement} checkbox
 * @returns {string[]}
 */
export function parseAllowedActions(checkbox) {
    if (checkbox && checkbox.dataset && checkbox.dataset.allowedActions !== undefined) {
        return checkbox.dataset.allowedActions.split(',').map((s) => s.trim()).filter(Boolean);
    }

    // Fallback: inspect the row's dropdown menu if data-allowed-actions is not present
    const actions = [];
    const row = checkbox && checkbox.closest ? checkbox.closest('tr') : null;
    if (row) {
        const dropdown = row.querySelector('.dropdown-menu');
        if (dropdown) {
            const actionItems = dropdown.querySelectorAll('.dropdown-item, button, a');
            actionItems.forEach((item) => {
                const text = (item.textContent || '').toLowerCase().trim();
                const targetModal = item.getAttribute('data-bs-target') || '';
                if (targetModal.includes('cancelSubscriptionModal') ||
                    text.includes('cancel subscription') ||
                    text.includes('cancel price adjustment')) {
                    if (!actions.includes('cancel')) {
                        actions.push('cancel');
                    }
                    if (!actions.includes('cancel_subscription')) {
                        actions.push('cancel_subscription');
                    }
                }
            });
        }
    }
    return actions;
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

    const selectionMap = new Map();

    /**
     * Shows a bulk action button only if EVERY selected subscription/price adjustment allows it
     * (i.e. it appears in that row's Actions dropdown).
     */
    function updateAllowedBulkActions() {
        const selected = Array.from(selectionMap.values());
        const count = selected.length;

        bulkBar.querySelectorAll('button[name="bulk_action"]').forEach((btn) => {
            const action = btn.value;
            const allowed =
                count > 0 &&
                selected.every((item) => {
                    if (!Array.isArray(item.allowedActions)) return false;
                    if (item.allowedActions.includes(action)) return true;
                    if (action === 'cancel' && item.allowedActions.includes('cancel_subscription')) return true;
                    if (action === 'cancel_subscription' && item.allowedActions.includes('cancel')) return true;
                    return false;
                });

            const target = btn.closest('li') || btn;
            target.classList.toggle('d-none', !allowed);
            btn.disabled = !allowed;
        });

        // If dropdown exists in bulk bar, hide it if none of its options are enabled
        bulkBar.querySelectorAll('.bulk-status-dropdown, .dropdown').forEach((dropdown) => {
            const hasVisibleOption = Array.from(
                dropdown.querySelectorAll('button[name="bulk_action"]')
            ).some((btn) => !btn.disabled);
            dropdown.classList.toggle('d-none', !hasVisibleOption);
        });
    }

    function getCheckboxKey(cb) {
        const $cb = $(cb);
        const subId = $cb.val();
        const itemIdx = $cb.data('item-index');
        return (itemIdx !== undefined && itemIdx !== null && itemIdx !== '') ? `${subId}:${itemIdx}` : subId.toString();
    }

    function updateBulkBar() {
        const count = selectionMap.size;
        const countSpan = bulkBar.querySelector('.selected-count');
        if (countSpan) {
            countSpan.textContent = count.toString();
        }

        if (count > 0) {
            bulkBar.classList.remove('d-none');
        } else {
            bulkBar.classList.add('d-none');
        }

        // Synchronize checkboxes in current DOM page with selectionMap
        const allRowNodes = tableApi.rows().nodes();
        $(allRowNodes).each(function () {
            const $cb = $(this).find('.subscription-row-checkbox');
            if ($cb.length) {
                const subId = getCheckboxKey($cb);
                const isSelected = selectionMap.has(subId);
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
                if (selectionMap.has(getCheckboxKey($cb))) {
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

        // Restrict bulk actions based on available actions in the dropdown for selected rows
        updateAllowedBulkActions();
    }

    function toggleAllVisible(isChecked) {
        const activeRows = tableApi.rows({ search: 'applied' }).nodes();
        $(activeRows).each(function () {
            const $cb = $(this).find('.subscription-row-checkbox');
            if ($cb.length) {
                const subId = getCheckboxKey($cb);
                if (isChecked) {
                    selectionMap.set(subId, { id: subId, allowedActions: parseAllowedActions($cb.get(0)) });
                } else {
                    selectionMap.delete(subId);
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
        const subId = getCheckboxKey(this);
        if (this.checked) {
            selectionMap.set(subId, { id: subId, allowedActions: parseAllowedActions(this) });
        } else {
            selectionMap.delete(subId);
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

    function clearSelections() {
        selectionMap.clear();
        updateBulkBar();
    }

    // Clear selection button
    const clearBtn = bulkBar.querySelector('.clear-selection-btn');
    if (clearBtn && !clearBtn.dataset.bulkBound) {
        clearBtn.dataset.bulkBound = 'true';
        clearBtn.addEventListener('click', function (e) {
            e.preventDefault();
            clearSelections();
        });
    }

    // Form submission: inject hidden inputs for all selected subscriptions across all pages
    if (bulkForm && !bulkForm.dataset.bulkFormBound) {
        bulkForm.dataset.bulkFormBound = 'true';
        bulkForm.addEventListener('submit', function (e) {
            if (e.submitter && e.submitter.disabled) {
                e.preventDefault();
                return;
            }

            // Remove previously appended hidden inputs
            bulkForm.querySelectorAll('input[name="subscription_ids[]"]').forEach((el) => el.remove());

            if (selectionMap.size === 0) {
                e.preventDefault();
                return;
            }

            selectionMap.forEach((entry, subId) => {
                const hiddenInput = document.createElement('input');
                hiddenInput.setAttribute('type', 'hidden');
                hiddenInput.setAttribute('name', 'subscription_ids[]');
                hiddenInput.setAttribute('value', subId.toString());
                bulkForm.appendChild(hiddenInput);
            });

            // Clear selection after submitting action so container does not linger
            clearSelections();
        });

        bulkForm.addEventListener('turbo:submit-end', function () {
            clearSelections();
        });
    }

    // Modal and form submission for bulk cancellation
    const cancelModal = document.getElementById(`cancelSubscriptionModal-bulk-${effectiveTableId}`);
    const bulkCancelForm = document.getElementById(`bulk_cancel_form_${effectiveTableId}`);

    if (cancelModal && !cancelModal.dataset.bulkBound) {
        cancelModal.dataset.bulkBound = 'true';
        cancelModal.addEventListener('show.bs.modal', function (e) {
            const count = selectionMap.size;
            if (count === 0) {
                e.preventDefault();
                return;
            }
            const countEl = cancelModal.querySelector('.bulk-cancel-count');
            if (countEl) countEl.textContent = count.toString();

            const isSingle = count === 1;
            const singleType = cancelModal.dataset.itemType || 'Subscription';
            const pluralType = cancelModal.dataset.itemTypePlural || `${singleType}s`;
            const lowerSingleType = singleType.toLowerCase();
            const lowerPluralType = pluralType.toLowerCase();

            const titleEl = cancelModal.querySelector('.bulk-cancel-title-type');
            if (titleEl) titleEl.textContent = isSingle ? singleType : pluralType;

            const bodyTypeEl = cancelModal.querySelector('.bulk-cancel-body-type');
            if (bodyTypeEl) bodyTypeEl.textContent = isSingle ? lowerSingleType : lowerPluralType;

            const bodyTargetEl = cancelModal.querySelector('.bulk-cancel-body-type-target');
            if (bodyTargetEl) bodyTargetEl.textContent = isSingle ? `This ${lowerSingleType}` : `The ${lowerPluralType}`;

            const keepBtn = cancelModal.querySelector('.bulk-cancel-keep-btn');
            if (keepBtn) keepBtn.textContent = `Keep ${isSingle ? singleType : pluralType}`;

            const submitLabel = cancelModal.querySelector('.bulk-cancel-submit-label');
            if (submitLabel) submitLabel.textContent = isSingle ? singleType : pluralType;
        });
    }

    if (bulkCancelForm && !bulkCancelForm.dataset.bulkFormBound) {
        bulkCancelForm.dataset.bulkFormBound = 'true';
        bulkCancelForm.addEventListener('submit', function (e) {
            // Remove previously appended hidden inputs
            bulkCancelForm.querySelectorAll('input[name="subscription_ids[]"]').forEach((el) => el.remove());

            if (selectionMap.size === 0) {
                e.preventDefault();
                return;
            }

            selectionMap.forEach((entry, subId) => {
                const hiddenInput = document.createElement('input');
                hiddenInput.setAttribute('type', 'hidden');
                hiddenInput.setAttribute('name', 'subscription_ids[]');
                hiddenInput.setAttribute('value', subId.toString());
                bulkCancelForm.appendChild(hiddenInput);
            });

            // Dismiss modal before submitting if bootstrap is available
            if (cancelModal && window.bootstrap && window.bootstrap.Modal) {
                const modalInstance = window.bootstrap.Modal.getInstance(cancelModal);
                if (modalInstance) {
                    modalInstance.hide();
                }
            }

            clearSelections();
        });

        bulkCancelForm.addEventListener('turbo:submit-end', function () {
            clearSelections();
        });
    }

    document.addEventListener('turbo:before-cache', function () {
        clearSelections();
    });

    // When DataTable is redrawn (page change, search, sort), re-synchronize state
    tableApi.off('draw.subsBulk').on('draw.subsBulk', function () {
        updateBulkBar();
    });

    // Initial state check
    updateBulkBar();
}

function initSubscriptionsPage(eventOrForce = false) {
    if (!window.location.pathname.includes("/subscriptions")) return;
    if (document.documentElement.hasAttribute('data-turbo-preview')) return;

    if (typeof $ === 'undefined' || !$.fn.DataTable) {
        console.warn("DataTables not loaded yet, deferring initialization.");
        setTimeout(initSubscriptionsPage, 100);
        return;
    }

    const forceReinit =
        eventOrForce === true ||
        Boolean(eventOrForce && eventOrForce.type === 'popstate');

    const initial = getInitialTableState();

    // Determine and restore top-level tab (sales vs purchases)
    const rawTopTab = (initial.tab || '').toLowerCase();
    const purchasesBtn = document.getElementById('purchases-tab');
    const currentTopTab = VALID_TOP_TABS.includes(rawTopTab)
        ? rawTopTab
        : (purchasesBtn && purchasesBtn.classList.contains('active') ? 'purchases' : 'sales');

    const topTabBtn = document.getElementById(`${currentTopTab}-tab`);
    if (topTabBtn) {
        activateTabElement(topTabBtn);
        syncSubscriptionsDropdownLinks(currentTopTab);
    }

    // Restore inner subscription status tab (active, finished, cancelled) for active top tab
    const rawStatusParam = (initial.status || initial.subtab || '').toLowerCase();
    let currentSubStatus = 'active';
    if (VALID_SUB_STATUSES.includes(rawStatusParam)) {
        currentSubStatus = rawStatusParam;
        setStoredSubStatus(currentTopTab, false, currentSubStatus);
    } else if (initial.tab || initial.status || initial.subtab) {
        currentSubStatus = 'active';
        setStoredSubStatus(currentTopTab, false, 'active');
    } else {
        const activeSubBtn = document.querySelector(`#${currentTopTab}SubscriptionTabs button.active`);
        currentSubStatus = (activeSubBtn && parseSubStatusFromTabId(activeSubBtn.id)) || 'active';
    }
    const innerSubTabBtn = document.getElementById(`${currentTopTab}-${currentSubStatus}-tab`);
    if (innerSubTabBtn) {
        activateTabElement(innerSubTabBtn);
    }

    // Restore inner price adjustment status tab (active, finished, cancelled) for active top tab
    const rawPaStatusParam = (initial.pa_status || '').toLowerCase();
    let currentPaStatus = 'active';
    if (VALID_SUB_STATUSES.includes(rawPaStatusParam)) {
        currentPaStatus = rawPaStatusParam;
        setStoredSubStatus(currentTopTab, true, currentPaStatus);
    } else if (initial.pa_status) {
        currentPaStatus = 'active';
        setStoredSubStatus(currentTopTab, true, 'active');
    } else {
        const activePaBtn = document.querySelector(`#${currentTopTab}PriceAdjustmentTabs button.active`);
        currentPaStatus = (activePaBtn && parseSubStatusFromTabId(activePaBtn.id)) || 'active';
    }
    const innerPaTabBtn = document.getElementById(`${currentTopTab}-${currentPaStatus}-pa-tab`);
    if (innerPaTabBtn) {
        activateTabElement(innerPaTabBtn);
    }

    // Also restore stored inner tabs for the inactive top-level tab in the background
    // so switching between Sales and Purchases after a refresh preserves each pane's inner tab state
    const otherTopTab = currentTopTab === 'sales' ? 'purchases' : 'sales';
    const otherSubStatus = getStoredSubStatus(otherTopTab, false) || 'active';
    const otherPaStatus = getStoredSubStatus(otherTopTab, true) || 'active';
    const otherSubBtn = document.getElementById(`${otherTopTab}-${otherSubStatus}-tab`);
    const otherPaBtn = document.getElementById(`${otherTopTab}-${otherPaStatus}-pa-tab`);
    if (otherSubBtn) activateTabElement(otherSubBtn);
    if (otherPaBtn) activateTabElement(otherPaBtn);

    $('.subscription-table').each(function() {
        const tableNode = this;
        const tableId = $(tableNode).attr('id');

        if ($.fn.DataTable.isDataTable(tableNode)) {
            if (!forceReinit) {
                return;
            }
            const dt = $(tableNode).DataTable();
            dt.destroy();
        }

        // Attach capture-phase listener to stop DataTables Responsive from toggling row collapse when interactive elements are clicked
        if (!tableNode.dataset.responsiveFixAttached) {
            tableNode.addEventListener('click', function(e) {
                // Allow dropdown items, modal triggers, and turbo actions to bubble normally
                if (e.target.closest('.dropdown-menu, [data-turbo-method], [data-bs-toggle="modal"], [data-bs-toggle="dropdown"]')) {
                    return;
                }

                if (e.target.closest('a, button, input, select, textarea, label')) {
                    e.stopPropagation();
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
            if (!forceReinit) {
                return;
            }
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
    $('#subscriptionTypeTabs button[data-bs-toggle="tab"]')
        .off('click.subs shown.bs.tab.subs')
        .on('click.subs shown.bs.tab.subs', function (e) {
            const tabId = ($(e.currentTarget).attr('id') || '').replace('-tab', '');
            if (!VALID_TOP_TABS.includes(tabId)) return;

            const { subStatus, paStatus } = getActivePaneSubStatuses(tabId);
            updateUrlParams({
                tab: tabId,
                status: subStatus === 'active' ? null : subStatus,
                pa_status: paStatus === 'active' ? null : paStatus
            });
            syncSubscriptionsDropdownLinks(tabId);

            if (e.type === 'shown') {
                setTimeout(function () {
                    $.fn.dataTable
                        .tables({ visible: true, api: true })
                        .columns.adjust()
                        .responsive.recalc();
                }, 150);
            }
        });

    // Also recalculate when inner status tabs (subscriptions or price adjustments) are clicked and sync URL params
    const innerTabsSelector = '#salesSubscriptionTabs button[data-bs-toggle="tab"], #salesPriceAdjustmentTabs button[data-bs-toggle="tab"], #purchasesSubscriptionTabs button[data-bs-toggle="tab"], #purchasesPriceAdjustmentTabs button[data-bs-toggle="tab"]';
    $(innerTabsSelector)
        .off('click.subs_inner shown.bs.tab.subs_inner')
        .on('click.subs_inner shown.bs.tab.subs_inner', function (e) {
            const tabBtnId = $(e.currentTarget).attr('id') || '';
            const topTab = tabBtnId.startsWith('purchases-') ? 'purchases' : 'sales';
            const isPa = tabBtnId.endsWith('-pa-tab');
            const status = parseSubStatusFromTabId(tabBtnId);

            if (status) {
                setStoredSubStatus(topTab, isPa, status);
                const paramKey = isPa ? 'pa_status' : 'status';
                const currentTabParam = getUrlParam('tab');
                updateUrlParams({
                    tab: topTab === 'purchases' ? 'purchases' : (currentTabParam === 'sales' ? 'sales' : null),
                    [paramKey]: status === 'active' ? null : status
                }, { clearPage: true });
            }

            if (e.type === 'shown') {
                setTimeout(function () {
                    $.fn.dataTable
                        .tables({ visible: true, api: true })
                        .columns.adjust()
                        .responsive.recalc();
                }, 100);
            }
        });

    // Ensure single-item cancel modals redirect back to the current tab/subtab URL state
    $('div[id^="cancelSubscriptionModal-"]')
        .off('show.bs.modal.subs_cancel')
        .on('show.bs.modal.subs_cancel', function () {
            const redirectInput = this.querySelector('input[name="redirect_to"]');
            if (redirectInput) {
                redirectInput.value = window.location.pathname + window.location.search;
            }
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
