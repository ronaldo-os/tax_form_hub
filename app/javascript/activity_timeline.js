/**
 * Activity Timeline Module
 * Provides chronological audit tracking for Tax Submissions and Invoices.
 * Styled uniformly with the Submission Overview modal.
 * Adheres strictly to SecureCoder safe DOM manipulation guidelines (no unsafe innerHTML for dynamic user content).
 */

let currentActivities = [];
let lastTrackableType = null;
let lastTrackableId = null;

/**
 * Ensures the Activity Timeline modal element exists in the DOM.
 * If not present, dynamically creates and injects the uniform modal structure.
 *
 * @returns {HTMLElement} The modal element
 */
export function ensureTimelineModalElement() {
  let modalEl = document.getElementById('activityTimelineModal');
  if (modalEl) return modalEl;

  if (typeof document === 'undefined' || !document.body) return null;

  modalEl = document.createElement('div');
  modalEl.className = 'modal fade';
  modalEl.id = 'activityTimelineModal';
  modalEl.tabIndex = -1;
  modalEl.setAttribute('aria-hidden', 'true');

  modalEl.innerHTML = `
    <div class="modal-dialog modal-dialog-centered modal-xl">
      <div class="modal-content">
        <div class="modal-header border-0">
          <h5 class="modal-title" id="activityTimelineModalLabel">Activity Timeline</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body" id="activityTimelineModalBody">
          <div id="activityTimelineLoading" class="text-center p-5">
            <div class="spinner-border text-primary" role="status"></div>
            <p class="mt-3">Loading...</p>
          </div>
          <div id="activityTimelineError" class="alert alert-danger d-none my-3 d-flex align-items-center justify-content-between rounded-3" role="alert">
            <div class="d-flex align-items-center gap-2">
              <i class="fa-solid fa-triangle-exclamation"></i>
              <span id="activityTimelineErrorMessage">Failed to load activity history.</span>
            </div>
            <button type="button" class="btn btn-sm btn-outline-danger" id="activityRetryBtn">Retry</button>
          </div>
          <div id="activityTimelineContent" class="d-none">
            <div class="card shadow-sm border-0 mb-4">
              <div class="card-body p-4">
                <div class="row g-4">
                  <div class="col-md-3">
                    <p class="text-muted mb-1">Resource</p>
                    <p class="fw-semibold fs-6 mb-0" id="activitySummaryTitle">-</p>
                  </div>
                  <div class="col-md-3">
                    <p class="text-muted mb-1">Type</p>
                    <p class="fw-semibold fs-6 mb-0" id="activitySummaryType">-</p>
                  </div>
                  <div class="col-md-3">
                    <p class="text-muted mb-1">Total Activities</p>
                    <p class="fw-semibold fs-6 mb-0" id="activitySummaryCount">-</p>
                  </div>
                  <div class="col-md-3">
                    <p class="text-muted mb-1">Latest Activity</p>
                    <p class="fw-semibold fs-6 mb-0" id="activitySummaryLatest">-</p>
                  </div>
                </div>
              </div>
            </div>
            <div class="card shadow-sm border-0">
              <div class="card-header bg-light border-0 py-3 d-flex flex-wrap align-items-center justify-content-between gap-2">
                <h6 class="fw-bold mb-0">Activity History</h6>
                <div class="d-flex align-items-center gap-2">
                  <input type="text" class="form-control form-control-sm" id="activitySearchInput" placeholder="Filter activities..." style="max-width: 220px;">
                </div>
              </div>
              <div class="card-body p-0">
                <div class="table-responsive">
                  <table class="table table-hover align-middle mb-0" id="activityTimelineTable">
                    <thead class="table-light">
                      <tr>
                        <th style="width: 22%;" class="ps-4">Date &amp; Time</th>
                        <th style="width: 22%;">Company</th>
                        <th style="width: 16%;">Action</th>
                        <th style="width: 40%;" class="pe-4">Description &amp; Details</th>
                      </tr>
                    </thead>
                    <tbody id="activityTimelineList"></tbody>
                  </table>
                </div>
                <div id="activityTimelineEmpty" class="text-center py-5 d-none">
                  <p class="text-muted mb-0">No activities recorded yet.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  document.body.appendChild(modalEl);
  bindModalControls(modalEl);
  return modalEl;
}

/**
 * Shows the modal using Bootstrap 5, jQuery fallback, or standard DOM fallback.
 *
 * @param {HTMLElement} modalEl
 */
function showTimelineModal(modalEl) {
  if (!modalEl) return;
  bindModalControls(modalEl);

  // 1. Bootstrap 5 API
  try {
    const bs = (typeof bootstrap !== 'undefined' && bootstrap?.Modal)
      ? bootstrap
      : (window.bootstrap?.Modal ? window.bootstrap : null);

    if (bs && bs.Modal) {
      const instance = bs.Modal.getOrCreateInstance ? bs.Modal.getOrCreateInstance(modalEl) : new bs.Modal(modalEl);
      if (instance && typeof instance.show === 'function') {
        instance.show();
        return;
      }
    }
  } catch (err) {
    console.warn('[ActivityTimeline] bootstrap.Modal.show error:', err);
  }

  // 2. jQuery Bootstrap modal fallback
  try {
    if (window.$ && typeof window.$(modalEl).modal === 'function') {
      window.$(modalEl).modal('show');
      return;
    }
  } catch (err) {
    console.warn('[ActivityTimeline] $.modal show error:', err);
  }

  // 3. Direct DOM fallback
  modalEl.classList.add('show');
  modalEl.style.display = 'block';
  modalEl.removeAttribute('aria-hidden');
  modalEl.setAttribute('aria-modal', 'true');
  document.body.classList.add('modal-open');

  let backdrop = document.querySelector('.activity-modal-backdrop-fallback');
  if (!backdrop) {
    backdrop = document.createElement('div');
    backdrop.className = 'modal-backdrop fade show activity-modal-backdrop-fallback';
    backdrop.addEventListener('click', () => hideTimelineModal(modalEl));
    document.body.appendChild(backdrop);
  }
}

/**
 * Hides the modal across all mechanisms.
 *
 * @param {HTMLElement} modalEl
 */
function hideTimelineModal(modalEl) {
  if (!modalEl) return;

  try {
    const bs = (typeof bootstrap !== 'undefined' && bootstrap?.Modal)
      ? bootstrap
      : (window.bootstrap?.Modal ? window.bootstrap : null);

    if (bs && bs.Modal) {
      const instance = bs.Modal.getInstance ? bs.Modal.getInstance(modalEl) : null;
      if (instance && typeof instance.hide === 'function') {
        instance.hide();
      }
    }
  } catch (err) {}

  try {
    if (window.$ && typeof window.$(modalEl).modal === 'function') {
      window.$(modalEl).modal('hide');
    }
  } catch (err) {}

  modalEl.classList.remove('show');
  modalEl.style.display = 'none';
  modalEl.setAttribute('aria-hidden', 'true');
  modalEl.removeAttribute('aria-modal');
  document.body.classList.remove('modal-open');
  document.querySelectorAll('.activity-modal-backdrop-fallback').forEach(el => el.remove());
}

/**
 * Binds dismiss actions and controls on the modal.
 *
 * @param {HTMLElement} modalEl
 */
function bindModalControls(modalEl) {
  if (!modalEl) return;

  // Dismiss buttons
  modalEl.querySelectorAll('[data-bs-dismiss="modal"]').forEach(btn => {
    if (!btn.dataset.dismissBound) {
      btn.dataset.dismissBound = 'true';
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        hideTimelineModal(modalEl);
      });
    }
  });

  // Search input filter inside modal
  const searchInput = modalEl.querySelector('#activitySearchInput');
  if (searchInput && !searchInput.dataset.filterBound) {
    searchInput.dataset.filterBound = 'true';
    searchInput.addEventListener('input', function () {
      filterActivitiesTable(this.value.trim().toLowerCase());
    });
  }

  // Retry button
  const retryBtn = modalEl.querySelector('#activityRetryBtn');
  if (retryBtn && !retryBtn.dataset.retryBound) {
    retryBtn.dataset.retryBound = 'true';
    retryBtn.addEventListener('click', function () {
      if (lastTrackableType && lastTrackableId) {
        fetchAndRenderActivities(lastTrackableType, lastTrackableId);
      }
    });
  }
}

/**
 * Opens the Activity Timeline modal and fetches activity events.
 *
 * @param {string} trackableType - 'Invoice' or 'TaxSubmission'
 * @param {number|string} trackableId - The record ID
 * @param {string} resourceTitle - Formatted title for display
 */
export function openTimelineModal(trackableType, trackableId, resourceTitle) {
  lastTrackableType = trackableType;
  lastTrackableId = trackableId;

  const modalEl = ensureTimelineModalElement();
  if (!modalEl) return;

  const modalTitle = modalEl.querySelector('#activityTimelineModalLabel');
  if (modalTitle) {
    modalTitle.textContent = `Activity Timeline - ${resourceTitle || 'Resource'}`;
  }

  const searchInput = modalEl.querySelector('#activitySearchInput');
  if (searchInput) searchInput.value = '';

  showTimelineModal(modalEl);
  fetchAndRenderActivities(trackableType, trackableId, resourceTitle);
}

/**
 * Fetches activities from the backend API and safely renders them into the table.
 */
function fetchAndRenderActivities(trackableType, trackableId, resourceTitle) {
  const modalEl = ensureTimelineModalElement();
  if (!modalEl) return;

  const loadingEl = modalEl.querySelector('#activityTimelineLoading');
  const errorEl = modalEl.querySelector('#activityTimelineError');
  const contentEl = modalEl.querySelector('#activityTimelineContent');
  const emptyEl = modalEl.querySelector('#activityTimelineEmpty');
  const listEl = modalEl.querySelector('#activityTimelineList');
  const tableEl = modalEl.querySelector('#activityTimelineTable');

  // Summary Elements
  const summaryTitle = modalEl.querySelector('#activitySummaryTitle');
  const summaryType = modalEl.querySelector('#activitySummaryType');
  const summaryCount = modalEl.querySelector('#activitySummaryCount');
  const summaryLatest = modalEl.querySelector('#activitySummaryLatest');

  if (loadingEl) loadingEl.classList.remove('d-none');
  if (errorEl) errorEl.classList.add('d-none');
  if (contentEl) contentEl.classList.add('d-none');
  if (emptyEl) emptyEl.classList.add('d-none');
  if (listEl) listEl.replaceChildren();

  const url = `/activities?trackable_type=${encodeURIComponent(trackableType)}&trackable_id=${encodeURIComponent(trackableId)}`;

  fetch(url, {
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest'
    }
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error(`Server returned HTTP ${response.status}`);
      }
      return response.json();
    })
    .then((data) => {
      if (loadingEl) loadingEl.classList.add('d-none');

      if (!data || !data.success) {
        throw new Error(data?.error || 'Unable to load activity history.');
      }

      currentActivities = data.activities || [];
      const totalCount = currentActivities.length;

      // Populate Overview Summary Card (Uniform with Submission Overview)
      if (summaryTitle) summaryTitle.textContent = resourceTitle || `${trackableType} #${trackableId}`;
      if (summaryType) summaryType.textContent = trackableType === 'Invoice' ? 'Invoice' : 'Tax Submission';
      if (summaryCount) summaryCount.textContent = `${totalCount} ${totalCount === 1 ? 'event' : 'events'}`;
      if (summaryLatest) {
        summaryLatest.textContent = currentActivities[0]?.formatted_date || currentActivities[0]?.time_ago || 'No activity';
      }

      if (contentEl) contentEl.classList.remove('d-none');

      if (totalCount === 0) {
        if (tableEl) tableEl.classList.add('d-none');
        if (emptyEl) emptyEl.classList.remove('d-none');
        return;
      }

      if (tableEl) tableEl.classList.remove('d-none');
      if (emptyEl) emptyEl.classList.add('d-none');

      renderActivitiesTable(currentActivities, listEl);
    })
    .catch((err) => {
      console.error('[ActivityTimeline] Error loading activities:', err);
      if (loadingEl) loadingEl.classList.add('d-none');
      if (errorEl) {
        const msgEl = modalEl.querySelector('#activityTimelineErrorMessage');
        if (msgEl) msgEl.textContent = err.message || 'Failed to load activity history.';
        errorEl.classList.remove('d-none');
      }
    });
}

/**
 * Safely renders activity records into table rows (tr).
 * Prevents Cross-Site Scripting (XSS) per SecureCoder guidelines (safe textContent and createElement).
 */
function renderActivitiesTable(activities, container) {
  if (!container) return;
  container.replaceChildren();

  activities.forEach((act, index) => {
    const tr = document.createElement('tr');
    tr.className = 'activity-row';
    tr.setAttribute('data-activity-id', act.id || index);

    // 1. Date & Time
    const tdDate = document.createElement('td');
    tdDate.className = 'ps-4';
    const dateDiv = document.createElement('div');
    dateDiv.className = 'fw-semibold text-body';
    dateDiv.textContent = act.formatted_date || act.created_at || '';
    tdDate.appendChild(dateDiv);

    if (act.time_ago) {
      const relTime = document.createElement('small');
      relTime.className = 'text-muted d-block';
      relTime.textContent = act.time_ago;
      tdDate.appendChild(relTime);
    }
    tr.appendChild(tdDate);

    // 2. Company
    const tdCompany = document.createElement('td');
    const companyWrap = document.createElement('div');
    companyWrap.className = 'd-flex align-items-center gap-1.5';

    const companyIcon = document.createElement('i');
    companyIcon.className = 'fa-solid fa-building text-secondary fs-6';
    companyWrap.appendChild(companyIcon);

    const companyName = document.createElement('span');
    if (act.company_name && act.company_name.trim().length > 0) {
      companyName.className = 'fw-medium text-body';
      companyName.textContent = act.company_name;
    } else {
      companyName.className = 'text-muted fst-italic';
      companyName.textContent = '—';
    }
    companyWrap.appendChild(companyName);
    tdCompany.appendChild(companyWrap);
    tr.appendChild(tdCompany);

    // 3. Action Badge (Uniform with Submission Overview rounded-pill badges)
    const tdAction = document.createElement('td');
    const badge = document.createElement('span');
    badge.className = `badge rounded-pill ${getActionBadgeClass(act.action)} px-3 py-2`;
    badge.textContent = formatActionLabel(act.action);
    tdAction.appendChild(badge);
    tr.appendChild(tdAction);

    // 4. Description & Details
    const tdDesc = document.createElement('td');
    tdDesc.className = 'pe-4';

    const descDiv = document.createElement('div');
    descDiv.className = 'fw-medium text-body';
    descDiv.textContent = act.description || 'Activity recorded';
    tdDesc.appendChild(descDiv);

    // Details/Diffs box (Uniform with Submission Overview details box style)
    if (act.metadata && typeof act.metadata === 'object' && Object.keys(act.metadata).length > 0) {
      const detailsBox = buildMetadataDetails(act.metadata, act.action);
      if (detailsBox) {
        tdDesc.appendChild(detailsBox);
      }
    }
    tr.appendChild(tdDesc);

    container.appendChild(tr);
  });
}

/**
 * Returns badge class matching the standard Submission Overview color schemes.
 */
function getActionBadgeClass(action) {
  switch (action) {
    case 'invoice_paid':
    case 'tax_processed':
    case 'invoice_unarchived':
      return 'bg-success';
    case 'tax_submitted':
    case 'invoice_sent':
    case 'invoice_status_changed':
      return 'bg-info text-dark';
    case 'tax_status_updated':
    case 'invoice_amount_updated':
      return 'bg-warning text-dark';
    case 'invoice_created':
      return 'bg-primary';
    case 'invoice_archived':
    default:
      return 'bg-secondary';
  }
}

/**
 * Builds safe metadata details elements (matching _details.erb style: p-2 bg-light rounded small text-muted).
 */
function buildMetadataDetails(metadata, action) {
  const container = document.createElement('div');
  container.className = 'p-2 bg-light rounded small text-muted mt-2';

  let hasContent = false;

  // Case A: Amount Updated Diff
  if (metadata.old_amount !== undefined && metadata.new_amount !== undefined) {
    const row = document.createElement('div');
    row.className = 'd-flex align-items-center gap-2';

    const label = document.createElement('span');
    label.textContent = 'Amount:';
    row.appendChild(label);

    const oldSpan = document.createElement('span');
    oldSpan.className = 'text-danger text-decoration-line-through';
    oldSpan.textContent = formatCurrency(metadata.old_amount, metadata.currency);
    row.appendChild(oldSpan);

    const arrow = document.createElement('i');
    arrow.className = 'fa-solid fa-arrow-right fs-9 text-muted';
    row.appendChild(arrow);

    const newSpan = document.createElement('span');
    newSpan.className = 'text-success fw-bold';
    newSpan.textContent = formatCurrency(metadata.new_amount, metadata.currency);
    row.appendChild(newSpan);

    container.appendChild(row);
    hasContent = true;
  }

  // Case B: Status Updated Diff
  if (metadata.old_status && metadata.new_status) {
    const row = document.createElement('div');
    row.className = 'd-flex align-items-center gap-2';

    const label = document.createElement('span');
    label.textContent = 'Status:';
    row.appendChild(label);

    const oldBadge = document.createElement('span');
    oldBadge.className = 'badge bg-secondary px-2 py-1';
    oldBadge.textContent = capitalize(metadata.old_status);
    row.appendChild(oldBadge);

    const arrow = document.createElement('i');
    arrow.className = 'fa-solid fa-arrow-right fs-9 text-muted';
    row.appendChild(arrow);

    const newBadge = document.createElement('span');
    newBadge.className = 'badge bg-primary px-2 py-1';
    newBadge.textContent = capitalize(metadata.new_status);
    row.appendChild(newBadge);

    container.appendChild(row);
    hasContent = true;
  }

  // Case C: Tax Submission document attachments
  if (metadata.form_2307_attached || metadata.deposit_slip_attached) {
    const row = document.createElement('div');
    row.className = 'd-flex flex-wrap align-items-center gap-2';

    const docLabel = document.createElement('span');
    docLabel.textContent = 'Documents:';
    row.appendChild(docLabel);

    if (metadata.form_2307_attached) {
      const f2307 = document.createElement('span');
      f2307.className = 'badge bg-info text-dark px-2 py-1';
      f2307.textContent = 'Form 2307';
      row.appendChild(f2307);
    }

    if (metadata.deposit_slip_attached) {
      const ds = document.createElement('span');
      ds.className = 'badge bg-success px-2 py-1';
      const count = metadata.deposit_slip_count || 1;
      ds.textContent = count > 1 ? `Deposit Slips (${count})` : 'Deposit Slip';
      row.appendChild(ds);
    }

    container.appendChild(row);
    hasContent = true;
  }

  return hasContent ? container : null;
}

/**
 * Human-friendly labels for action keys.
 */
function formatActionLabel(action) {
  const map = {
    invoice_created: 'Created',
    invoice_paid: 'Paid',
    invoice_amount_updated: 'Amount Change',
    invoice_status_changed: 'Status Update',
    invoice_sent: 'Sent',
    tax_submitted: 'Submitted',
    tax_status_updated: 'Reviewed',
    tax_processed: 'Processed',
    invoice_archived: 'Archived',
    invoice_unarchived: 'Restored'
  };
  return map[action] || action.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

/**
 * Currency formatter.
 */
function formatCurrency(amount, currency = 'PHP') {
  const val = parseFloat(amount);
  if (isNaN(val)) return String(amount);
  return `${currency} ${val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/**
 * Filters visible table rows by keyword.
 */
function filterActivitiesTable(query) {
  const modalEl = document.getElementById('activityTimelineModal');
  if (!modalEl) return;

  const rows = modalEl.querySelectorAll('#activityTimelineList .activity-row');
  let visibleCount = 0;

  rows.forEach((row) => {
    const text = row.textContent.toLowerCase();
    if (!query || text.includes(query)) {
      row.classList.remove('d-none');
      visibleCount++;
    } else {
      row.classList.add('d-none');
    }
  });

  const summaryCount = modalEl.querySelector('#activitySummaryCount');
  if (summaryCount) {
    summaryCount.textContent = `${visibleCount} ${visibleCount === 1 ? 'event' : 'events'}`;
  }
}

function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Delegated click event handler for all timeline trigger buttons.
 * Uses native closest() to handle clicks on the button, icon, or padding.
 */
function handleTimelineClick(event) {
  const btn = event.target && event.target.closest ? event.target.closest('.open-activity-timeline-btn') : null;
  if (!btn) return;

  event.preventDefault();
  event.stopPropagation();

  const trackableType = btn.getAttribute('data-trackable-type') || btn.dataset?.trackableType;
  const trackableId = btn.getAttribute('data-trackable-id') || btn.dataset?.trackableId;
  const resourceTitle = btn.getAttribute('data-resource-title') || btn.dataset?.resourceTitle || 'Resource';

  if (!trackableType || !trackableId) {
    console.warn('[ActivityTimeline] Missing trackable-type or trackable-id on button:', btn);
    return;
  }

  openTimelineModal(trackableType, trackableId, resourceTitle);
}

/**
 * Primary initialization function.
 */
export function initActivityTimeline() {
  const modalEl = ensureTimelineModalElement();
  if (modalEl) {
    bindModalControls(modalEl);
  }

  if (typeof window !== 'undefined' && window.$) {
    try {
      window.$(document).off('click.activityTimeline', '.open-activity-timeline-btn')
        .on('click.activityTimeline', '.open-activity-timeline-btn', function (e) {
          e.preventDefault();
          e.stopPropagation();
          const $b = window.$(this);
          const tType = $b.data('trackable-type') || $b.attr('data-trackable-type');
          const tId = $b.data('trackable-id') || $b.attr('data-trackable-id');
          const rTitle = $b.data('resource-title') || $b.attr('data-resource-title') || 'Resource';
          if (tType && tId) {
            openTimelineModal(tType, tId, rTitle);
          }
        });
    } catch (err) {}
  }
}

// Global document click listener (capture phase: runs first and cannot be swallowed)
if (typeof document !== 'undefined') {
  document.removeEventListener('click', handleTimelineClick, true);
  document.addEventListener('click', handleTimelineClick, true);

  document.removeEventListener('click', handleTimelineClick, false);
  document.addEventListener('click', handleTimelineClick, false);
}

// Expose on global window object
if (typeof window !== 'undefined') {
  window.initActivityTimeline = initActivityTimeline;
  window.openActivityTimelineModal = openTimelineModal;
  window.ensureTimelineModalElement = ensureTimelineModalElement;

  document.addEventListener('turbo:load', initActivityTimeline);
  document.addEventListener('turbo:render', initActivityTimeline);
  document.addEventListener('DOMContentLoaded', initActivityTimeline);

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    initActivityTimeline();
  }
}
