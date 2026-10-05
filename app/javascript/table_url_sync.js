/**
 * Table URL State Synchronizer
 * Synchronizes DataTable filter states (tab, subtab, status, search, page, type, company)
 * with browser URL query parameters using window.history.replaceState.
 *
 * Enables bookmarking and sharing of filtered views (e.g. "?status=Pending&search=October").
 */

export function getUrlParams() {
    return new URLSearchParams(window.location.search);
}

export function getUrlParam(key) {
    return getUrlParams().get(key);
}

/**
 * Update URL query parameters using window.history.replaceState.
 * @param {Object} updates - Key/value pairs to set or delete (if null/undefined/empty string)
 * @param {Object} [options] - Options: { clearPage: boolean }
 */
export function updateUrlParams(updates, options = {}) {
    try {
        const url = new URL(window.location.href);
        const searchParams = url.searchParams;

        Object.entries(updates).forEach(([key, value]) => {
            if (value === null || value === undefined || value === '') {
                searchParams.delete(key);
            } else {
                searchParams.set(key, String(value));
            }
        });

        if (options.clearPage) {
            searchParams.delete('page');
        }

        const newSearch = searchParams.toString();
        const newUrl = url.pathname + (newSearch ? '?' + newSearch : '') + url.hash;
        window.history.replaceState({}, '', newUrl);
    } catch (err) {
        console.warn('Failed to update URL parameters:', err);
    }
}

/**
 * Standard debounce implementation
 */
export function debounce(func, wait = 300) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func.apply(this, args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Extract safe initial state for a table from URL query params.
 */
export function getInitialTableState() {
    const params = getUrlParams();
    const pageRaw = parseInt(params.get('page'), 10);
    const page = (!isNaN(pageRaw) && pageRaw > 0) ? pageRaw : 1;

    const sort = params.get('sort') || params.get('sort_col') || params.get('order_col') || null;
    let dir = (params.get('dir') || params.get('sort_dir') || params.get('order_dir') || '').toLowerCase();
    if (dir !== 'asc' && dir !== 'desc') {
        dir = null;
    }

    return {
        tab: params.get('tab') || null,
        subtab: params.get('subtab') || null,
        status: params.get('status') || null,
        search: params.get('search') || null,
        page: page,
        type: params.get('type') || null,
        company: params.get('company') || null,
        sort: sort,
        dir: dir
    };
}

/**
 * Resolves a sort parameter (column index or column name/slug) to a DataTables [[colIndex, 'asc'|'desc']] array.
 * @param {jQuery} $table - jQuery table element
 * @param {string|number|null} sortParam - Column index or header data-data / data-name / slug
 * @param {string|null} dirParam - 'asc' or 'desc'
 * @param {Array} defaultOrder - Default DataTables order, e.g. [[0, 'asc']]
 * @returns {Array} - DataTables order array e.g. [[colIdx, 'desc']]
 */
export function resolveSortOrder($table, sortParam, dirParam, defaultOrder = [[0, 'asc']]) {
    if (!sortParam) return defaultOrder;

    const dir = (dirParam === 'desc') ? 'desc' : 'asc';

    // Case 1: Numeric column index
    const colIdxRaw = parseInt(sortParam, 10);
    if (!isNaN(colIdxRaw) && String(colIdxRaw) === String(sortParam).trim()) {
        return [[colIdxRaw, dir]];
    }

    // Case 2: Named column via header matching (data-data, data-name, or slugified text)
    if ($table && $table.length) {
        const headers = $table.find('thead th').toArray();
        const cleanTarget = String(sortParam).trim().toLowerCase();

        for (let i = 0; i < headers.length; i++) {
            const $th = $(headers[i]);
            const dataAttr = ($th.data('data') || $th.attr('data-data') || '').toString().toLowerCase();
            const nameAttr = ($th.data('name') || $th.attr('data-name') || '').toString().toLowerCase();
            const textSlug = $th.text().trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');

            if (dataAttr === cleanTarget || nameAttr === cleanTarget || textSlug === cleanTarget) {
                return [[i, dir]];
            }
        }
    }

    return defaultOrder;
}

/**
 * Helper to bind table sorting synchronization with URL
 * @param {object} tableApi - DataTables API instance
 * @param {object} [options] - Optional config { defaultOrder, sortKey = 'sort', dirKey = 'dir' }
 */
export function bindOrderSync(tableApi, options = {}) {
    if (!tableApi) return;
    const sortKey = options.sortKey || 'sort';
    const dirKey = options.dirKey || 'dir';
    const defaultOrder = options.defaultOrder || null;
    const tableNode = tableApi.table ? tableApi.table().node() : tableApi;
    const $table = $(tableNode);

    // Guard against initial draw wiping URL params on page refresh
    let readyToSync = false;
    setTimeout(() => { readyToSync = true; }, 150);

    $table.off('order.dt.tableUrlSync').on('order.dt.tableUrlSync', function () {
        if (!readyToSync) return;

        const currentOrder = tableApi.order();
        if (!currentOrder || !currentOrder.length) return;

        const [colIdx, colDir] = currentOrder[0];

        // Try to find a human-friendly column identifier (e.g. "issue_date", "counterparty", "total")
        let colIdent = colIdx;
        try {
            const header = tableApi.column(colIdx).header();
            if (header) {
                const $th = $(header);
                const dataAttr = $th.attr('data-data') || $th.data('data') || $th.attr('data-name') || $th.data('name');
                if (dataAttr && typeof dataAttr === 'string' && dataAttr !== 'checkbox' && dataAttr !== 'actions') {
                    colIdent = dataAttr;
                }
            }
        } catch (e) {}

        // Check if this matches default order
        let isDefault = false;
        if (defaultOrder && defaultOrder.length) {
            const [defCol, defDir] = defaultOrder[0];
            if (defCol === colIdx && defDir === colDir) {
                isDefault = true;
            }
        }

        if (isDefault) {
            updateUrlParams({ [sortKey]: null, [dirKey]: null });
        } else {
            updateUrlParams({ [sortKey]: colIdent, [dirKey]: colDir });
        }
    });
}

/**
 * Helper to bind debounced search input synchronization with URL
 * @param {jQuery} $searchInput - Input element for DataTable search
 * @param {Function} [onChange] - Optional callback
 */
export function bindSearchInputSync($searchInput, onChange) {
    if (!$searchInput || !$searchInput.length) return;

    const debouncedUpdate = debounce(function (val) {
        updateUrlParams({ search: val || null }, { clearPage: true });
        if (typeof onChange === 'function') {
            onChange(val);
        }
    }, 300);

    $searchInput.off('input.tableUrlSync').on('input.tableUrlSync', function () {
        debouncedUpdate($(this).val().trim());
    });
}

/**
 * Helper to bind pagination synchronization with URL
 * @param {object} tableApi - DataTables API instance
 */
export function bindPaginationSync(tableApi) {
    if (!tableApi) return;
    const tableNode = tableApi.table ? tableApi.table().node() : tableApi;
    const $table = $(tableNode);

    let readyToSync = false;
    setTimeout(() => { readyToSync = true; }, 150);

    $table.off('page.dt.tableUrlSync').on('page.dt.tableUrlSync', function () {
        if (!readyToSync) return;
        const info = tableApi.page.info ? tableApi.page.info() : null;
        const currentPage = (info ? info.page : tableApi.page()) + 1;
        updateUrlParams({ page: currentPage > 1 ? currentPage : null });
    });
}
