/**
 * Tax Submissions Bulk Actions Manager
 * Handles multi-row checkbox selection, state synchronization across pages,
 * and bulk action toolbar submissions for tax submissions tables.
 * Compliant with Secure Coding Guidelines (strict DOM API, no innerHTML).
 */

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
      const text = dropdown.textContent.toLowerCase();
      if (text.includes('unarchive')) {
        actions.push('unarchive');
      } else if (text.includes('archive')) {
        actions.push('archive');
      }
      if (text.includes('delete')) {
        actions.push('destroy');
      }
    }
  }
  return actions;
}

export function setupTaxSubmissionsBulkActions(tableApi, tableId) {
  if (!tableApi) return;

  const $table = $(tableApi.table().node());
  const effectiveTableId = tableId || $table.attr('id');
  if (!effectiveTableId) return;

  const bulkBar = document.getElementById(`bulk_action_bar_${effectiveTableId}`);
  const bulkForm = document.getElementById(`bulk_form_${effectiveTableId}`);
  const headerCheckbox = document.getElementById(`header_checkbox_${effectiveTableId}`);
  const masterBulkCheckbox = document.getElementById(`master_bulk_${effectiveTableId}`);

  if (!bulkBar || !bulkForm) return;

  /**
   * Shows a bulk action button only if EVERY selected submission allows it
   * (i.e. it appears in that submission's row Actions dropdown).
   */
  function updateAllowedBulkActions() {
    const allNodes = tableApi.rows().nodes();
    const checkedBoxes = $(allNodes).find('.submission-row-checkbox:checked');
    const count = checkedBoxes.length;

    const checkedEntries = [];
    checkedBoxes.each(function () {
      checkedEntries.push(parseAllowedActions(this));
    });

    bulkBar.querySelectorAll('button[name="bulk_action"]').forEach((btn) => {
      const action = btn.value;
      const allowed =
        count > 0 &&
        checkedEntries.every((allowedActions) => Array.isArray(allowedActions) && allowedActions.includes(action));

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

  function updateBulkBar() {
    const allNodes = tableApi.rows().nodes();
    const checkedBoxes = $(allNodes).find('.submission-row-checkbox:checked');
    const count = checkedBoxes.length;
    const totalCount = $(allNodes).find('.submission-row-checkbox').length;

    // Safely update selected count text using textContent
    const countSpan = bulkBar.querySelector('.selected-count');
    if (countSpan) {
      countSpan.textContent = count.toString();
    }

    // Toggle bulk bar visibility
    if (count > 0) {
      bulkBar.classList.remove('d-none');
    } else {
      bulkBar.classList.add('d-none');
    }

    // Visually highlight selected rows
    $(allNodes).each(function () {
      const isChecked = $(this).find('.submission-row-checkbox').is(':checked');
      $(this).toggleClass('row-selected table-active', isChecked);
    });

    // Synchronize header checkbox and master bulk bar checkbox
    const isAllSelected = totalCount > 0 && count === totalCount;
    const isIndeterminate = count > 0 && count < totalCount;

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

  function toggleAll(isChecked) {
    // Only toggle rows matching the currently active search / filter
    const activeRows = tableApi.rows({ search: 'applied' }).nodes();
    $(activeRows).find('.submission-row-checkbox').prop('checked', isChecked);
    updateBulkBar();
  }

  // Header checkbox toggle
  if (headerCheckbox && !headerCheckbox.dataset.bulkBound) {
    headerCheckbox.dataset.bulkBound = 'true';
    headerCheckbox.addEventListener('change', function () {
      toggleAll(this.checked);
    });
  }

  // Master checkbox in bulk bar toggle
  if (masterBulkCheckbox && !masterBulkCheckbox.dataset.bulkBound) {
    masterBulkCheckbox.dataset.bulkBound = 'true';
    masterBulkCheckbox.addEventListener('change', function () {
      toggleAll(this.checked);
    });
  }

  // Row checkbox change (delegated to table node for dynamic / paginated rows)
  $table.off('change.submissionCheckbox', '.submission-row-checkbox').on('change.submissionCheckbox', '.submission-row-checkbox', function () {
    updateBulkBar();
  });

  function clearAllSelections() {
    const allNodes = tableApi.rows().nodes();
    $(allNodes).find('.submission-row-checkbox').prop('checked', false);
    updateBulkBar();
  }

  // Clear selection button
  const clearBtn = bulkBar.querySelector('.clear-selection-btn');
  if (clearBtn && !clearBtn.dataset.bulkBound) {
    clearBtn.dataset.bulkBound = 'true';
    clearBtn.addEventListener('click', function (e) {
      e.preventDefault();
      clearAllSelections();
    });
  }

  // Form submission: gather selected row checkboxes across all DataTable pages and append hidden inputs
  if (bulkForm && !bulkForm.dataset.bulkFormBound) {
    bulkForm.dataset.bulkFormBound = 'true';
    bulkForm.addEventListener('submit', function (e) {
      if (e.submitter && e.submitter.disabled) {
        e.preventDefault();
        return;
      }

      // Remove previously appended hidden inputs
      bulkForm.querySelectorAll('input[name="tax_submission_ids[]"]').forEach(el => el.remove());

      const allNodes = tableApi.rows().nodes();
      const checkedBoxes = $(allNodes).find('.submission-row-checkbox:checked');

      if (checkedBoxes.length === 0) {
        e.preventDefault();
        return;
      }

      checkedBoxes.each(function () {
        const hiddenInput = document.createElement('input');
        hiddenInput.setAttribute('type', 'hidden');
        hiddenInput.setAttribute('name', 'tax_submission_ids[]');
        hiddenInput.setAttribute('value', this.value);
        bulkForm.appendChild(hiddenInput);
      });

      // Clear selection after submitting action so container does not linger
      clearAllSelections();
    });

    bulkForm.addEventListener('turbo:submit-end', function () {
      clearAllSelections();
    });
  }

  document.addEventListener('turbo:before-cache', function () {
    clearAllSelections();
  });

  // When DataTable is redrawn (page change, search, sort), re-evaluate state
  tableApi.off('draw.taxBulk').on('draw.taxBulk', function () {
    updateBulkBar();
  });

  // Initial state check
  updateBulkBar();
}
