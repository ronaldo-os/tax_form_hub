/**
 * DataTables Column Visibility & Preference Persistence
 *
 * Allows users to hide/show individual DataTable columns via an accessible
 * dropdown control in the DataTable toolbar and persists their preferences
 * per table in localStorage.
 *
 * Security & Reliability:
 * - All DOM elements are built with createElement/textContent (no innerHTML).
 * - Only non-sensitive boolean column visibility flags are stored in localStorage.
 * - localStorage reads/writes are guarded with try/catch and strict schema checks.
 * - Essential control columns (checkboxes, Actions) remain locked visible, and
 *   at least one toggleable data column is always kept visible.
 */

const STORAGE_PREFIX = 'dt_col_vis_v1:';

/**
 * Normalizes a URL pathname so dynamic numeric IDs share a single preference key
 * (e.g. "/subscriptions/42" -> "/subscriptions/:id").
 *
 * @param {string} pathname
 * @returns {string}
 */
export function normalizePathForStorage(pathname) {
  if (!pathname || typeof pathname !== 'string') return '/';
  const cleaned = pathname
    .replace(/\/\d+(?=\/|$)/g, '/:id')
    .replace(/\/+$/, '');
  return cleaned || '/';
}

/**
 * Builds a deterministic localStorage key for a DataTable instance.
 *
 * @param {object} api - DataTables API instance
 * @param {string} [customKey]
 * @returns {string}
 */
export function getColumnStorageKey(api, customKey) {
  if (customKey && typeof customKey === 'string') {
    return `${STORAGE_PREFIX}${customKey}`;
  }
  const tableNode = api && typeof api.table === 'function' ? api.table().node() : null;
  const tableId = (tableNode && tableNode.id) ? tableNode.id : '';
  const dataKey = tableNode ? (tableNode.getAttribute('data-colvis-key') || '') : '';
  const fallbackClass = (tableNode && tableNode.className)
    ? tableNode.className.split(/\s+/).filter(Boolean).slice(0, 2).join('_')
    : 'table';
  const identifier = dataKey || tableId || fallbackClass;
  const pathKey = normalizePathForStorage(
    typeof window !== 'undefined' && window.location ? window.location.pathname : '/'
  );
  return `${STORAGE_PREFIX}${pathKey}:${identifier}`;
}

/**
 * Reads and validates saved column visibility preferences from localStorage.
 *
 * @param {string} storageKey
 * @returns {Object<string, boolean>}
 */
export function loadColumnPreferences(storageKey) {
  if (typeof window === 'undefined' || !window.localStorage || !storageKey) {
    return {};
  }
  try {
    const raw = window.localStorage.getItem(storageKey);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {};
    }
    const sanitized = {};
    Object.keys(parsed).forEach((key) => {
      if (typeof parsed[key] === 'boolean' && key.length > 0 && key.length <= 120) {
        sanitized[key] = parsed[key];
      }
    });
    return sanitized;
  } catch (e) {
    return {};
  }
}

/**
 * Persists column visibility preferences to localStorage.
 * Removes the key when all toggleable columns are visible (default state).
 *
 * @param {string} storageKey
 * @param {Object<string, boolean>} prefs
 */
export function saveColumnPreferences(storageKey, prefs) {
  if (typeof window === 'undefined' || !window.localStorage || !storageKey) {
    return;
  }
  try {
    const hasHidden = Object.values(prefs).some((visible) => visible === false);
    if (!hasHidden) {
      window.localStorage.removeItem(storageKey);
    } else {
      window.localStorage.setItem(storageKey, JSON.stringify(prefs));
    }
  } catch (e) {
    // Ignore storage quota or private-mode errors gracefully
  }
}

/**
 * Determines whether a column should be locked (excluded from hide/show menu).
 *
 * @param {HTMLElement|null} headerEl
 * @param {string} label
 * @param {number} index
 * @param {number[]} lockedIndices
 * @returns {boolean}
 */
function isColumnLocked(headerEl, label, index, lockedIndices) {
  if (lockedIndices.includes(index)) return true;
  if (!headerEl) return true;
  if (headerEl.getAttribute('data-colvis-locked') === 'true') return true;
  if (headerEl.classList.contains('no-colvis')) return true;
  if (headerEl.querySelector('input[type="checkbox"]')) return true;

  const dataAttr = (headerEl.getAttribute('data-data') || '').toLowerCase().trim();
  if (dataAttr === 'checkbox' || dataAttr === 'actions' || dataAttr === 'action') {
    return true;
  }

  const normalizedLabel = label.toLowerCase().trim();
  if (!normalizedLabel || normalizedLabel === 'actions' || normalizedLabel === 'action') {
    return true;
  }

  return false;
}

/**
 * Extracts toggleable column metadata from a DataTable API instance.
 *
 * @param {object} api
 * @param {number[]} lockedIndices
 * @returns {Array<{index: number, key: string, label: string}>}
 */
function collectToggleableColumns(api, lockedIndices = []) {
  const indices = api.columns().indexes().toArray();
  const usedKeys = new Set();
  const columns = [];

  indices.forEach((index) => {
    const headerEl = api.column(index).header();
    const label = headerEl ? headerEl.textContent.replace(/\s+/g, ' ').trim() : '';

    if (isColumnLocked(headerEl, label, index, lockedIndices)) {
      return;
    }

    const dataAttr = headerEl ? (headerEl.getAttribute('data-data') || '').trim() : '';
    let baseKey = dataAttr || label.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
    if (!baseKey) baseKey = `col_${index}`;

    let key = baseKey;
    if (usedKeys.has(key)) {
      key = `${baseKey}_${index}`;
    }
    usedKeys.add(key);

    columns.push({ index, key, label });
  });

  return columns;
}

/**
 * Updates colspan on an empty-table row cell after column visibility changes.
 *
 * @param {object} api
 */
function syncEmptyRowColspan(api) {
  try {
    const tableNode = api.table().node();
    if (!tableNode) return;
    const emptyCell = tableNode.querySelector('tbody td.dataTables_empty');
    if (emptyCell) {
      const visibleCount = api.columns(':visible').count();
      if (visibleCount > 0) {
        emptyCell.setAttribute('colspan', String(visibleCount));
      }
    }
  } catch (e) {}
}

/**
 * Attaches the "Columns" hide/show dropdown control to a DataTable's toolbar
 * and applies any saved column visibility preferences from localStorage.
 *
 * @param {object} api - DataTables API instance
 * @param {object} [options]
 * @param {string} [options.storageKey] - Optional explicit localStorage key suffix
 * @param {number[]} [options.lockedIndices] - Optional extra column indices to lock visible
 */
export function initDataTableColumnVisibility(api, options = {}) {
  if (!api || typeof api.columns !== 'function' || typeof api.table !== 'function') {
    return;
  }

  const containerEl = api.table().container();
  const tableNode = api.table().node();
  if (!containerEl || !tableNode) return;

  const lockedIndices = Array.isArray(options.lockedIndices) ? options.lockedIndices : [];
  const toggleableColumns = collectToggleableColumns(api, lockedIndices);
  if (toggleableColumns.length <= 1) return;

  const storageKey = getColumnStorageKey(api, options.storageKey);
  const savedPrefs = loadColumnPreferences(storageKey);

  // Determine initial visibility for each toggleable column, guaranteeing at least 1 remains visible
  const resolvedVisibility = {};
  let visibleToggleableCount = 0;

  toggleableColumns.forEach((col) => {
    const isVisible = Object.prototype.hasOwnProperty.call(savedPrefs, col.key)
      ? savedPrefs[col.key] === true
      : api.column(col.index).visible() !== false;
    resolvedVisibility[col.key] = isVisible;
    if (isVisible) visibleToggleableCount += 1;
  });

  // Safety guard: if saved prefs somehow hid every toggleable column, reset all to visible
  if (visibleToggleableCount === 0) {
    toggleableColumns.forEach((col) => {
      resolvedVisibility[col.key] = true;
    });
    saveColumnPreferences(storageKey, resolvedVisibility);
  }

  // Apply saved visibility to DataTable without triggering a server-side AJAX redraw
  let changedOnInit = false;
  toggleableColumns.forEach((col) => {
    const desired = resolvedVisibility[col.key];
    const current = api.column(col.index).visible();
    if (current !== desired) {
      api.column(col.index).visible(desired, false);
      changedOnInit = true;
    }
  });

  if (changedOnInit) {
    api.columns.adjust();
    if (api.responsive && typeof api.responsive.recalc === 'function') {
      api.responsive.recalc();
    }
    syncEmptyRowColspan(api);
  }

  // Locate toolbar host (div.dataTables_length) and remove any stale colvis control
  const existingControls = containerEl.querySelectorAll('.dt-colvis-dropdown');
  existingControls.forEach((el) => el.remove());

  let toolbarHost = containerEl.querySelector('div.dataTables_length');
  if (!toolbarHost) {
    toolbarHost = containerEl.querySelector('.row:first-child > div:first-child') || containerEl;
  }

  toolbarHost.classList.add('d-flex', 'flex-wrap', 'align-items-center', 'gap-2');

  const safeTableId = (tableNode.id || `dt_${Math.random().toString(36).slice(2, 8)}`)
    .replace(/[^a-zA-Z0-9_-]/g, '_');

  // Build dropdown wrapper using safe DOM APIs
  const dropdown = document.createElement('div');
  dropdown.className = 'dropdown dt-colvis-dropdown';

  const triggerBtn = document.createElement('button');
  triggerBtn.type = 'button';
  triggerBtn.className = 'btn btn-sm dt-colvis-btn dropdown-toggle';
  triggerBtn.id = `dt_colvis_btn_${safeTableId}`;
  triggerBtn.setAttribute('data-bs-toggle', 'dropdown');
  triggerBtn.setAttribute('data-bs-auto-close', 'outside');
  triggerBtn.setAttribute('aria-expanded', 'false');
  triggerBtn.setAttribute('aria-label', 'Show or hide table columns');
  triggerBtn.title = 'Show or hide columns';

  const icon = document.createElement('i');
  icon.className = 'fa-solid fa-table-columns';
  icon.setAttribute('aria-hidden', 'true');

  const labelSpan = document.createElement('span');
  labelSpan.className = 'dt-colvis-label';
  labelSpan.textContent = 'Columns';

  const hiddenBadge = document.createElement('span');
  hiddenBadge.className = 'dt-colvis-badge badge rounded-pill d-none';

  triggerBtn.appendChild(icon);
  triggerBtn.appendChild(labelSpan);
  triggerBtn.appendChild(hiddenBadge);

  const menu = document.createElement('div');
  menu.className = 'dropdown-menu dropdown-menu-end dt-colvis-menu shadow';
  menu.setAttribute('aria-labelledby', triggerBtn.id);

  // Header
  const header = document.createElement('div');
  header.className = 'dt-colvis-header d-flex align-items-center justify-content-between';

  const headerTitle = document.createElement('span');
  headerTitle.className = 'dt-colvis-title';
  headerTitle.textContent = 'Columns';

  const resetBtn = document.createElement('button');
  resetBtn.type = 'button';
  resetBtn.className = 'btn btn-link btn-sm p-0 dt-colvis-reset-btn text-decoration-none';
  resetBtn.textContent = 'Reset';
  resetBtn.title = 'Show all columns';

  header.appendChild(headerTitle);
  header.appendChild(resetBtn);

  // Checkbox list
  const listEl = document.createElement('div');
  listEl.className = 'dt-colvis-list';

  const checkboxMap = new Map();

  toggleableColumns.forEach((col) => {
    const itemLabel = document.createElement('label');
    itemLabel.className = 'dt-colvis-item form-check mb-0';
    const checkboxId = `dt_colvis_${safeTableId}_${col.index}`;
    itemLabel.setAttribute('for', checkboxId);

    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.className = 'form-check-input dt-colvis-checkbox';
    checkbox.id = checkboxId;
    checkbox.checked = resolvedVisibility[col.key] !== false;
    checkbox.dataset.colIndex = String(col.index);
    checkbox.dataset.colKey = col.key;

    const textSpan = document.createElement('span');
    textSpan.className = 'dt-colvis-item-text text-truncate';
    textSpan.textContent = col.label;
    textSpan.title = col.label;

    itemLabel.appendChild(checkbox);
    itemLabel.appendChild(textSpan);
    listEl.appendChild(itemLabel);

    checkboxMap.set(col.key, { checkbox, col, itemLabel });
  });

  // Footer
  const footer = document.createElement('div');
  footer.className = 'dt-colvis-footer d-flex align-items-center justify-content-between';

  const countText = document.createElement('span');
  countText.className = 'dt-colvis-count';

  const savedHint = document.createElement('span');
  savedHint.className = 'dt-colvis-saved';
  const savedIcon = document.createElement('i');
  savedIcon.className = 'fa-solid fa-floppy-disk me-1';
  savedIcon.setAttribute('aria-hidden', 'true');
  savedHint.appendChild(savedIcon);
  savedHint.appendChild(document.createTextNode('Auto-saved'));

  footer.appendChild(countText);
  footer.appendChild(savedHint);

  menu.appendChild(header);
  menu.appendChild(listEl);
  menu.appendChild(footer);

  dropdown.appendChild(triggerBtn);
  dropdown.appendChild(menu);

  // Prevent clicks inside menu from bubbling up to DataTables/table handlers
  menu.addEventListener('click', (e) => {
    e.stopPropagation();
  });

  function syncMenuState() {
    const visibleItems = [];
    toggleableColumns.forEach((col) => {
      const entry = checkboxMap.get(col.key);
      if (!entry) return;
      const isVisible = api.column(col.index).visible() !== false;
      entry.checkbox.checked = isVisible;
      if (isVisible) visibleItems.push(entry);
    });

    const totalCount = toggleableColumns.length;
    const visibleCount = visibleItems.length;
    const hiddenCount = totalCount - visibleCount;

    // Lock the last remaining visible column so the user can never hide every column
    toggleableColumns.forEach((col) => {
      const entry = checkboxMap.get(col.key);
      if (!entry) return;
      const lockLast = visibleCount <= 1 && entry.checkbox.checked;
      entry.checkbox.disabled = lockLast;
      entry.itemLabel.classList.toggle('is-locked', lockLast);
      entry.itemLabel.title = lockLast ? 'At least one column must remain visible' : '';
    });

    if (hiddenCount > 0) {
      hiddenBadge.textContent = String(hiddenCount);
      hiddenBadge.classList.remove('d-none');
      hiddenBadge.title = `${hiddenCount} column${hiddenCount === 1 ? '' : 's'} hidden`;
      triggerBtn.classList.add('has-hidden-columns');
      resetBtn.disabled = false;
      resetBtn.classList.remove('disabled', 'opacity-50');
    } else {
      hiddenBadge.textContent = '';
      hiddenBadge.classList.add('d-none');
      triggerBtn.classList.remove('has-hidden-columns');
      resetBtn.disabled = true;
      resetBtn.classList.add('disabled', 'opacity-50');
    }

    countText.textContent = `${visibleCount} of ${totalCount} shown`;
  }

  function persistCurrentState() {
    const prefs = {};
    toggleableColumns.forEach((col) => {
      prefs[col.key] = api.column(col.index).visible() !== false;
    });
    saveColumnPreferences(storageKey, prefs);
  }

  // Handle checkbox toggles
  checkboxMap.forEach(({ checkbox, col }) => {
    checkbox.addEventListener('change', () => {
      const desired = checkbox.checked;

      if (!desired) {
        const currentlyVisible = toggleableColumns.filter(
          (c) => api.column(c.index).visible() !== false
        );
        if (currentlyVisible.length <= 1) {
          checkbox.checked = true;
          return;
        }
      }

      api.column(col.index).visible(desired, false);
      api.columns.adjust();
      if (api.responsive && typeof api.responsive.recalc === 'function') {
        api.responsive.recalc();
      }
      syncEmptyRowColspan(api);
      persistCurrentState();
      syncMenuState();
    });
  });

  // Handle Reset button
  resetBtn.addEventListener('click', (e) => {
    e.preventDefault();
    toggleableColumns.forEach((col) => {
      if (api.column(col.index).visible() === false) {
        api.column(col.index).visible(true, false);
      }
    });
    api.columns.adjust();
    if (api.responsive && typeof api.responsive.recalc === 'function') {
      api.responsive.recalc();
    }
    syncEmptyRowColspan(api);
    persistCurrentState();
    syncMenuState();
  });

  syncMenuState();
  toolbarHost.appendChild(dropdown);
}
