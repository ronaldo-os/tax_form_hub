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
    <div class="modal-content atl-modal">
      <div class="modal-header atl-header">
        <h5 class="modal-title" id="activityTimelineModalLabel">Activity Timeline</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body atl-body" id="activityTimelineModalBody">

        <div id="activityTimelineLoading" class="text-center p-5">
          <div class="spinner-border text-primary" role="status"></div>
          <p class="mt-3">Loading...</p>
        </div>

        <div id="activityTimelineError" class="alert alert-danger d-none my-3 d-flex align-items-center justify-content-between" role="alert">
          <div class="d-flex align-items-center gap-2">
            <i class="fa-solid fa-triangle-exclamation"></i>
            <span id="activityTimelineErrorMessage">Failed to load activity history.</span>
          </div>
          <button type="button" class="btn btn-sm btn-outline-danger" id="activityRetryBtn">Retry</button>
        </div>

        <div id="activityTimelineContent" class="d-none">

          <!-- Section 1: Overview -->
          <section class="atl-section">
            <div class="atl-section-head">
              <span class="atl-section-title"><i class="fa-solid fa-circle-info"></i> Overview</span>
            </div>
            <div class="atl-section-body">
              <div class="row g-3">
                <div class="col-6 col-md-3">
                  <div class="atl-label">Resource</div>
                  <div class="atl-value" id="activitySummaryTitle">-</div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="atl-label">Type</div>
                  <div class="atl-value" id="activitySummaryType">-</div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="atl-label">Total Activities</div>
                  <div class="atl-value" id="activitySummaryCount">-</div>
                </div>
                <div class="col-6 col-md-3">
                  <div class="atl-label">Latest Activity</div>
                  <div class="atl-value" id="activitySummaryLatest">-</div>
                </div>
              </div>
            </div>
          </section>

          <!-- Section 2: Payment Receipts (Invoices only) -->
          <section id="activityPaymentSection" class="atl-section d-none">
            <div class="atl-section-head">
              <div class="d-flex align-items-center gap-2 flex-wrap">
                <span class="atl-section-title"><i class="fa-solid fa-receipt"></i> Payment Receipts</span>
                <span class="badge" id="activityPaymentStatusBadge">Sent</span>
                <span class="atl-muted small" id="activityPaymentSubtext"></span>
              </div>
              <button type="button" class="btn btn-sm btn-primary d-none" id="activityRecordPaymentBtn">
                <i class="fa-solid fa-plus"></i>
                <span id="activityRecordPaymentBtnText">Add Payment</span>
              </button>
            </div>
            <div class="atl-section-body">
              <div class="atl-metrics">
                <div class="atl-metric">
                  <div class="atl-label">Invoice Total</div>
                  <div class="atl-value" id="activityPaymentGrandTotal">-</div>
                </div>
                <div class="atl-metric">
                  <div class="atl-label">Total Paid</div>
                  <div class="atl-value">
                    <span class="text-success" id="activityPaymentTotalPaid">-</span>
                  </div>
                </div>
                <div class="atl-metric">
                  <div class="atl-label">Remaining Balance</div>
                  <div class="atl-value" id="activityPaymentRemainingBalance">-</div>
                </div>
              </div>
              <div class="progress atl-progress">
                <div class="progress-bar" id="activityPaymentProgressBar" role="progressbar" style="width: 0%;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100"></div>
              </div>

              <div id="activityPaymentTableWrapper" class="d-none mt-3">
                <div class="table-responsive">
                  <table class="table atl-table align-middle mb-0">
                    <thead>
                      <tr>
                        <th style="width: 25%;">Date &amp; Details</th>
                        <th style="width: 20%;">Method</th>
                        <th style="width: 20%;">Reference</th>
                        <th style="width: 15%;" class="text-end">Amount</th>
                        <th style="width: 15%;">Recorded By</th>
                        <th style="width: 5%;" class="text-center" id="activityPaymentActionsHeader"></th>
                      </tr>
                    </thead>
                    <tbody id="activityPaymentList"></tbody>
                  </table>
                </div>
              </div>

              <div id="activityPaymentEmpty" class="atl-empty mt-3 d-none">
                <span class="small atl-muted">No payment transactions recorded yet.</span>
                <button type="button" class="btn btn-link btn-sm p-0 ms-1 text-decoration-none d-none" id="activityPaymentEmptyRecordBtn">+ Mark as Partially Paid</button>
              </div>
            </div>
          </section>

          <!-- Section 3: Activity History -->
          <section class="atl-section mb-0">
            <div class="atl-section-head">
              <span class="atl-section-title"><i class="fa-solid fa-clock-rotate-left"></i> Activity History</span>
            </div>
            <div class="atl-section-body p-0">
              <div class="table-responsive">
                <table class="table atl-table align-middle mb-0" id="activityTimelineTable">
                  <thead>
                    <tr>
                      <th style="width: 20%;" class="ps-3">Date &amp; Time</th>
                      <th style="width: 18%;">Company</th>
                      <th style="width: 14%;">Action</th>
                      <th style="width: 48%;" class="pe-3">Description &amp; Details</th>
                    </tr>
                  </thead>
                  <tbody id="activityTimelineList"></tbody>
                </table>
              </div>
              <div id="activityTimelineEmpty" class="text-center py-5 d-none">
                <p class="atl-muted mb-0">No activities recorded yet.</p>
              </div>
            </div>
          </section>

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
  } catch (err) { }

  try {
    if (window.$ && typeof window.$(modalEl).modal === 'function') {
      window.$(modalEl).modal('hide');
    }
  } catch (err) { }

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

      // Populate Payment Receipts & History Section (Only for Invoices)
      if (data.payment_summary) {
        renderPaymentSummary(data.payment_summary, modalEl, trackableType, trackableId, resourceTitle);
      } else {
        const paymentSection = modalEl.querySelector('#activityPaymentSection');
        if (paymentSection) paymentSection.classList.add('d-none');
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
 * Retrieves CSRF token from document meta tag.
 */
function getCsrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : '';
}

/**
 * Handles opening record payment modal from within activity timeline modal.
 */
function triggerRecordPaymentModal(invoiceId) {
  const modalEl = document.getElementById('activityTimelineModal');
  if (modalEl) {
    hideTimelineModal(modalEl);
  }

  // Look for target modal in DOM
  const targetModalId = `recordPaymentModal-${invoiceId}`;
  const paymentModal = document.getElementById(targetModalId);

  if (paymentModal) {
    showBootstrapOrFallbackModal(paymentModal);
  } else {
    // If not in current DOM, navigate to invoice show view
    window.location.href = `/invoices/${invoiceId}`;
  }
}

/**
 * Shows modal using Bootstrap 5, jQuery, or DOM fallback.
 */
function showBootstrapOrFallbackModal(el) {
  if (!el) return;
  try {
    const bs = (typeof bootstrap !== 'undefined' && bootstrap?.Modal)
      ? bootstrap
      : (window.bootstrap?.Modal ? window.bootstrap : null);
    if (bs && bs.Modal) {
      const inst = bs.Modal.getOrCreateInstance ? bs.Modal.getOrCreateInstance(el) : new bs.Modal(el);
      inst.show();
      return;
    }
  } catch (e) { }

  if (window.$ && typeof window.$(el).modal === 'function') {
    window.$(el).modal('show');
    return;
  }

  el.classList.add('show');
  el.style.display = 'block';
  el.removeAttribute('aria-hidden');
  document.body.classList.add('modal-open');
}

/**
 * Renders the Payment Receipts and History summary section inside the Activity Timeline Modal.
 */
function renderPaymentSummary(summary, modalEl, trackableType, trackableId, resourceTitle) {
  if (!modalEl || !summary) return;

  const paymentSection = modalEl.querySelector('#activityPaymentSection');
  if (!paymentSection) return;

  // 1. Subtext
  const subtextEl = modalEl.querySelector('#activityPaymentSubtext');
  if (subtextEl) {
    const count = summary.payments_count || 0;
    subtextEl.textContent = count > 0
      ? (count === 1 ? '• 1 transaction' : `• ${count} transactions`)
      : '';
  }

  // 2. Status Badge
  const statusBadge = modalEl.querySelector('#activityPaymentStatusBadge');
  if (statusBadge) {
    statusBadge.textContent = summary.status_title || summary.status || '';
    statusBadge.className = `badge rounded-pill px-2.5 py-1 fw-semibold extra-small ${summary.status_badge_class || 'bg-secondary'}`;
  }

  // 3. Action Buttons (+ Mark as Partially Paid / Add Payment)
  const recordBtn = modalEl.querySelector('#activityRecordPaymentBtn');
  const recordBtnText = modalEl.querySelector('#activityRecordPaymentBtnText');
  const emptyRecordBtn = modalEl.querySelector('#activityPaymentEmptyRecordBtn');

  if (summary.can_record_payment) {
    if (recordBtn) {
      recordBtn.classList.remove('d-none');
      if (recordBtnText) {
        recordBtnText.textContent = (summary.payments_count > 0) ? 'Add Payment' : 'Mark as Partially Paid';
      }
      recordBtn.onclick = (e) => {
        e.preventDefault();
        triggerRecordPaymentModal(summary.invoice_id);
      };
    }
    if (emptyRecordBtn) {
      emptyRecordBtn.classList.remove('d-none');
      emptyRecordBtn.onclick = (e) => {
        e.preventDefault();
        triggerRecordPaymentModal(summary.invoice_id);
      };
    }
  } else {
    if (recordBtn) recordBtn.classList.add('d-none');
    if (emptyRecordBtn) emptyRecordBtn.classList.add('d-none');
  }

  // 4. Minimalist Metric Strip
  const grandTotalEl = modalEl.querySelector('#activityPaymentGrandTotal');
  const totalPaidEl = modalEl.querySelector('#activityPaymentTotalPaid');
  const remainingBalanceEl = modalEl.querySelector('#activityPaymentRemainingBalance');

  if (grandTotalEl) grandTotalEl.textContent = summary.formatted_grand_total || '-';
  if (totalPaidEl) totalPaidEl.textContent = summary.formatted_total_paid || '-';
  if (remainingBalanceEl) {
    remainingBalanceEl.textContent = summary.formatted_remaining_balance || '-';
    remainingBalanceEl.className = `fw-bold fs-6 ${summary.remaining_balance > 0 ? 'text-danger' : 'text-muted'}`;
  }

  // 5. Fulfillment Progress Bar & Badge
  const percentLabelEl = modalEl.querySelector('#activityPaymentPercentLabel');
  const progressBarEl = modalEl.querySelector('#activityPaymentProgressBar');
  const pct = Math.min(Math.max(summary.percent_paid || 0, 0), 100);

  if (percentLabelEl) {
    percentLabelEl.textContent = `${pct}%`;
    percentLabelEl.className = `badge ${pct === 100 ? 'bg-success-subtle text-success' : 'bg-primary-subtle text-primary'} extra-small px-1.5 py-0.5 rounded-pill`;
  }
  if (progressBarEl) {
    progressBarEl.style.width = `${pct}%`;
    progressBarEl.setAttribute('aria-valuenow', String(pct));
    progressBarEl.className = `progress-bar rounded-pill ${pct === 100 ? 'bg-success' : 'bg-primary'}`;
  }

  // 6. Payments Table vs Empty State
  const tableWrapper = modalEl.querySelector('#activityPaymentTableWrapper');
  const emptyWrapper = modalEl.querySelector('#activityPaymentEmpty');
  const listEl = modalEl.querySelector('#activityPaymentList');

  const payments = summary.payments || [];
  if (payments.length > 0) {
    if (tableWrapper) tableWrapper.classList.remove('d-none');
    if (emptyWrapper) emptyWrapper.classList.add('d-none');
    if (listEl) {
      renderPaymentReceiptsTable(payments, listEl, summary.can_record_payment, trackableType, trackableId, resourceTitle);
    }
  } else {
    if (tableWrapper) tableWrapper.classList.add('d-none');
    if (emptyWrapper) emptyWrapper.classList.remove('d-none');
    if (listEl) listEl.replaceChildren();
  }

  // Reveal the section
  paymentSection.classList.remove('d-none');
}

/**
 * Safely renders payment receipts list into table rows without XSS risks.
 */
function renderPaymentReceiptsTable(payments, tbody, canRecord, trackableType, trackableId, resourceTitle) {
  tbody.replaceChildren();

  payments.forEach((payment) => {
    const tr = document.createElement('tr');

    // 1. Date & Details (with inline note if present)
    const tdDate = document.createElement('td');
    tdDate.className = 'py-2';
    const dateDiv = document.createElement('div');
    dateDiv.className = 'fw-medium text-body';
    dateDiv.textContent = payment.payment_date || '';
    tdDate.appendChild(dateDiv);

    if (payment.notes && payment.notes.trim().length > 0) {
      const noteDiv = document.createElement('div');
      noteDiv.className = 'extra-small text-muted fst-italic mt-0.5 d-flex align-items-center gap-1';
      const noteIcon = document.createElement('i');
      noteIcon.className = 'fa-regular fa-note-sticky text-secondary fs-8';
      noteDiv.appendChild(noteIcon);
      const noteText = document.createElement('span');
      noteText.textContent = payment.notes;
      noteDiv.appendChild(noteText);
      tdDate.appendChild(noteDiv);
    }
    tr.appendChild(tdDate);

    // 2. Payment Method
    const tdMethod = document.createElement('td');
    tdMethod.className = 'py-2';
    const badge = document.createElement('span');
    badge.className = `badge ${payment.payment_method_badge_class || 'bg-light text-dark'} rounded-pill px-2 py-0.5 extra-small`;
    const icon = document.createElement('i');
    icon.className = `${payment.payment_method_icon || 'fa-solid fa-receipt'} me-1`;
    badge.appendChild(icon);
    badge.appendChild(document.createTextNode(payment.payment_method || ''));
    tdMethod.appendChild(badge);
    tr.appendChild(tdMethod);

    // 3. Reference Number
    const tdRef = document.createElement('td');
    tdRef.className = 'py-2';
    const code = document.createElement('code');
    code.className = 'font-monospace text-body bg-light-subtle px-1.5 py-0.5 rounded border border-secondary-subtle extra-small';
    code.textContent = payment.reference_number || '—';
    tdRef.appendChild(code);
    tr.appendChild(tdRef);

    // 4. Amount Paid
    const tdAmount = document.createElement('td');
    tdAmount.className = 'py-2 text-end fw-semibold text-success fs-7';
    tdAmount.textContent = payment.formatted_amount || '';
    tr.appendChild(tdAmount);

    // 5. Recorded By
    const tdUser = document.createElement('td');
    tdUser.className = 'py-2 text-muted extra-small';
    tdUser.textContent = payment.user_email || 'System';
    tr.appendChild(tdUser);

    // 6. Actions (Delete button)
    const tdAction = document.createElement('td');
    tdAction.className = 'py-2 text-center';
    if (payment.can_delete && payment.delete_path) {
      const delBtn = document.createElement('button');
      delBtn.type = 'button';
      delBtn.className = 'btn btn-link btn-xs text-danger p-0';
      delBtn.title = 'Remove payment receipt';
      const trashIcon = document.createElement('i');
      trashIcon.className = 'fa-solid fa-trash-can';
      delBtn.appendChild(trashIcon);

      delBtn.addEventListener('click', (e) => {
        e.preventDefault();
        if (!confirm('Are you sure you want to remove this payment receipt?')) return;

        delBtn.disabled = true;
        const csrfToken = getCsrfToken();
        fetch(payment.delete_path, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
          }
        })
          .then((res) => {
            if (res.ok) {
              fetchAndRenderActivities(trackableType, trackableId, resourceTitle);
            } else {
              alert('Failed to remove payment receipt.');
              delBtn.disabled = false;
            }
          })
          .catch(() => {
            alert('An error occurred while removing payment receipt.');
            delBtn.disabled = false;
          });
      });

      tdAction.appendChild(delBtn);
    } else {
      tdAction.textContent = '';
    }
    tr.appendChild(tdAction);

    tbody.appendChild(tr);
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
    case 'marked_as_paid':
    case 'tax_processed':
    case 'processed':
    case 'invoice_unarchived':
    case 'unarchived':
    case 'approved':
      return 'bg-success';
    case 'tax_submitted':
    case 'invoice_sent':
    case 'quote_sent':
    case 'reviewed':
    case 'tax_status_updated':
      return 'bg-info text-dark';
    case 'invoice_status_changed':
    case 'status_changed':
      return 'bg-primary';
    case 'payment_recorded':
      return 'bg-success text-white';
    case 'payment_removed':
    case 'rejected':
      return 'bg-danger text-white';
    case 'invoice_amount_updated':
    case 'amount_updated':
    case 'credit_note_created':
      return 'bg-warning text-dark';
    case 'invoice_created':
      return 'bg-primary';
    case 'invoice_updated':
    case 'invoice_archived':
    case 'archived':
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

  // Case D: Payment Recorded Details
  if (action === 'payment_recorded' && (metadata.amount_paid !== undefined || metadata.reference_number)) {
    const row = document.createElement('div');
    row.className = 'd-flex flex-wrap align-items-center gap-2';

    if (metadata.payment_method) {
      const methodBadge = document.createElement('span');
      methodBadge.className = 'badge bg-light text-dark border px-2 py-1';
      methodBadge.textContent = metadata.payment_method;
      row.appendChild(methodBadge);
    }

    if (metadata.reference_number) {
      const refSpan = document.createElement('code');
      refSpan.className = 'font-monospace text-body bg-light-subtle px-1.5 py-0.5 rounded border border-secondary-subtle extra-small';
      refSpan.textContent = `Ref: ${metadata.reference_number}`;
      row.appendChild(refSpan);
    }

    if (metadata.amount_paid !== undefined && metadata.amount_paid !== null) {
      const amtSpan = document.createElement('span');
      amtSpan.className = 'text-success fw-bold';
      amtSpan.textContent = formatCurrency(metadata.amount_paid, metadata.currency || 'PHP');
      row.appendChild(amtSpan);
    }

    container.appendChild(row);
    hasContent = true;
  }

  // Case E: Invoice Created Initial Total
  if (action === 'invoice_created' && metadata.total !== undefined && metadata.total !== null) {
    const row = document.createElement('div');
    row.className = 'd-flex align-items-center gap-2';
    const totalSpan = document.createElement('span');
    totalSpan.className = 'text-muted';
    totalSpan.textContent = `Invoice Total: ${formatCurrency(metadata.total, metadata.currency || 'PHP')}`;
    row.appendChild(totalSpan);
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
    marked_as_paid: 'Paid',
    payment_recorded: 'Payment',
    payment_removed: 'Payment Removed',
    approved: 'Approved',
    rejected: 'Rejected',
    invoice_amount_updated: 'Amount Change',
    amount_updated: 'Amount Change',
    invoice_status_changed: 'Status Update',
    status_changed: 'Status Update',
    invoice_sent: 'Sent',
    quote_sent: 'Sent',
    invoice_updated: 'Updated',
    tax_submitted: 'Submitted',
    tax_status_updated: 'Status Update',
    reviewed: 'Reviewed',
    tax_processed: 'Processed',
    processed: 'Processed',
    invoice_archived: 'Archived',
    archived: 'Archived',
    invoice_unarchived: 'Restored',
    unarchived: 'Restored',
    credit_note_created: 'Credit Note'
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
    } catch (err) { }
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
