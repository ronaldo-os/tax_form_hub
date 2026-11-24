import { hideSkeleton } from './skeleton_loader';
import { getUrlParam, updateUrlParams } from './table_url_sync';

const VALID_QUICK_FILTERS = ['all', 'recent', 'with_invoices', 'has_contact', 'has_website'];
const VALID_SORTS = ['name_asc', 'name_desc', 'newest', 'oldest'];

function applyNetworkQuickFilters({ syncUrl = true } = {}) {
    const grid = document.getElementById('network_cards_grid');
    if (!grid) return;

    const cards = Array.from(grid.querySelectorAll('.network-card-col'));
    const activePill = document.querySelector('#network_quick_filters_bar .network-filter-pill.active');
    const activeFilter = activePill ? (activePill.dataset.filter || 'all') : 'all';

    const searchInput = document.getElementById('network_connected_search');
    const industrySelect = document.getElementById('network_industry_filter');
    const ownershipSelect = document.getElementById('network_ownership_filter');
    const sortSelect = document.getElementById('network_sort_filter');

    const searchTerm = (searchInput ? searchInput.value : '').trim().toLowerCase();
    const selectedIndustry = (industrySelect ? industrySelect.value : '').trim().toLowerCase();
    const selectedOwnership = (ownershipSelect ? ownershipSelect.value : '').trim().toLowerCase();
    const selectedSort = (sortSelect ? sortSelect.value : 'name_asc') || 'name_asc';

    // Sort cards inside grid
    const sortedCards = cards.slice().sort((a, b) => {
        if (selectedSort === 'name_desc') {
            return (b.dataset.companyName || '').localeCompare(a.dataset.companyName || '');
        }
        if (selectedSort === 'newest') {
            return Number(b.dataset.createdAt || 0) - Number(a.dataset.createdAt || 0);
        }
        if (selectedSort === 'oldest') {
            return Number(a.dataset.createdAt || 0) - Number(b.dataset.createdAt || 0);
        }
        return (a.dataset.companyName || '').localeCompare(b.dataset.companyName || '');
    });

    sortedCards.forEach((card) => grid.appendChild(card));

    // Filter cards
    let visibleCount = 0;
    sortedCards.forEach((card) => {
        let matches = true;

        if (activeFilter === 'recent' && card.dataset.isRecent !== 'true') {
            matches = false;
        } else if (activeFilter === 'with_invoices' && card.dataset.hasInvoices !== 'true') {
            matches = false;
        } else if (activeFilter === 'has_contact' && card.dataset.hasContact !== 'true') {
            matches = false;
        } else if (activeFilter === 'has_website' && card.dataset.hasWebsite !== 'true') {
            matches = false;
        }

        if (matches && selectedIndustry && (card.dataset.industry || '') !== selectedIndustry) {
            matches = false;
        }

        if (matches && selectedOwnership && (card.dataset.ownership || '') !== selectedOwnership) {
            matches = false;
        }

        if (matches && searchTerm && !(card.dataset.searchText || '').includes(searchTerm)) {
            matches = false;
        }

        card.classList.toggle('d-none', !matches);
        if (matches) visibleCount += 1;
    });

    // Update count badge & empty state
    const totalCount = cards.length;
    const isFiltered = activeFilter !== 'all' || Boolean(searchTerm) || Boolean(selectedIndustry) || Boolean(selectedOwnership);
    const hasAnyControlModified = isFiltered || selectedSort !== 'name_asc';

    const countTextEl = document.getElementById('network_connected_count_text');
    if (countTextEl) {
        countTextEl.textContent = isFiltered
            ? `${visibleCount} of ${totalCount} Shown`
            : `${totalCount} Connected`;
    }

    const clearBtn = document.getElementById('network_clear_filters_btn');
    if (clearBtn) {
        clearBtn.classList.toggle('d-none', !hasAnyControlModified);
    }

    const emptyStateEl = document.getElementById('network_no_filter_matches');
    if (emptyStateEl) {
        emptyStateEl.classList.toggle('d-none', visibleCount > 0 || totalCount === 0);
    }

    if (syncUrl) {
        updateUrlParams({
            filter: activeFilter !== 'all' ? activeFilter : null,
            q: searchTerm || null,
            industry: selectedIndustry || null,
            ownership: selectedOwnership || null,
            sort: selectedSort !== 'name_asc' ? selectedSort : null
        });
    }
}

function setActiveNetworkPill(filterKey) {
    const normalized = VALID_QUICK_FILTERS.includes(filterKey) ? filterKey : 'all';
    document.querySelectorAll('#network_quick_filters_bar .network-filter-pill').forEach((btn) => {
        const isTarget = btn.dataset.filter === normalized;
        btn.classList.toggle('active', isTarget);
        btn.setAttribute('aria-pressed', isTarget ? 'true' : 'false');
    });
}

function resetNetworkQuickFilters() {
    setActiveNetworkPill('all');

    const searchInput = document.getElementById('network_connected_search');
    if (searchInput) searchInput.value = '';

    const industrySelect = document.getElementById('network_industry_filter');
    if (industrySelect) industrySelect.value = '';

    const ownershipSelect = document.getElementById('network_ownership_filter');
    if (ownershipSelect) ownershipSelect.value = '';

    const sortSelect = document.getElementById('network_sort_filter');
    if (sortSelect) sortSelect.value = 'name_asc';

    applyNetworkQuickFilters({ syncUrl: true });
}

function restoreNetworkFiltersFromUrl() {
    if (!document.getElementById('network_quick_filters_bar')) return;

    const urlFilter = (getUrlParam('filter') || '').toLowerCase();
    if (VALID_QUICK_FILTERS.includes(urlFilter)) {
        setActiveNetworkPill(urlFilter);
    }

    const urlQuery = getUrlParam('q');
    const searchInput = document.getElementById('network_connected_search');
    if (searchInput && urlQuery) {
        searchInput.value = urlQuery;
    }

    const urlIndustry = (getUrlParam('industry') || '').toLowerCase();
    const industrySelect = document.getElementById('network_industry_filter');
    if (industrySelect && urlIndustry) {
        industrySelect.value = urlIndustry;
    }

    const urlOwnership = (getUrlParam('ownership') || '').toLowerCase();
    const ownershipSelect = document.getElementById('network_ownership_filter');
    if (ownershipSelect && urlOwnership) {
        ownershipSelect.value = urlOwnership;
    }

    const urlSort = (getUrlParam('sort') || '').toLowerCase();
    const sortSelect = document.getElementById('network_sort_filter');
    if (sortSelect && VALID_SORTS.includes(urlSort)) {
        sortSelect.value = urlSort;
    }

    if (urlFilter || urlQuery || urlIndustry || urlOwnership || urlSort) {
        applyNetworkQuickFilters({ syncUrl: false });
    }
}

function initNetworksPage() {
    if (!window.location.pathname.includes('/networks')) return;

    hideSkeleton('networks_skeleton', 'networks_content');
    restoreNetworkFiltersFromUrl();

    // Quick filter pill clicks
    $(document)
        .off('click.network_filters', '#network_quick_filters_bar .network-filter-pill')
        .on('click.network_filters', '#network_quick_filters_bar .network-filter-pill', function () {
            setActiveNetworkPill(this.dataset.filter || 'all');
            applyNetworkQuickFilters({ syncUrl: true });
        });

    // Live search input on connected companies
    let filterSearchTimeout = null;
    $(document)
        .off('input.network_filters', '#network_connected_search')
        .on('input.network_filters', '#network_connected_search', function () {
            clearTimeout(filterSearchTimeout);
            filterSearchTimeout = setTimeout(() => {
                applyNetworkQuickFilters({ syncUrl: true });
            }, 80);
        });

    // Dropdown filters (industry, ownership, sort)
    $(document)
        .off('change.network_filters', '#network_industry_filter, #network_ownership_filter, #network_sort_filter')
        .on('change.network_filters', '#network_industry_filter, #network_ownership_filter, #network_sort_filter', function () {
            applyNetworkQuickFilters({ syncUrl: true });
        });

    // Clear / Reset buttons
    $(document)
        .off('click.network_filters', '#network_clear_filters_btn, .network-empty-reset-btn')
        .on('click.network_filters', '#network_clear_filters_btn, .network-empty-reset-btn', function (e) {
            e.preventDefault();
            resetNetworkQuickFilters();
        });
}

document.addEventListener('turbo:load', initNetworksPage);
document.addEventListener('DOMContentLoaded', initNetworksPage);
initNetworksPage();

let searchTimeout = null;

$(document)
    .off('input.network_add_search', '#company_search_input')
    .on('input.network_add_search', '#company_search_input', function () {
        const $searchForm = $('#network_search_form');

        if ($searchForm.length) {
            clearTimeout(searchTimeout);

            searchTimeout = setTimeout(function () {
                if ($searchForm[0].requestSubmit) {
                    $searchForm[0].requestSubmit();
                } else {
                    $searchForm.submit();
                }
            }, 50);
        }
    });
