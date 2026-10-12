/**
 * DataTable Dropdown Fix
 *
 * Several DataTables attach a capture-phase click listener on the <table> that calls
 * stopPropagation() for buttons/links (to stop DataTables Responsive from toggling rows).
 * Bootstrap 5 closes other open dropdowns via a *bubbling* click listener on document
 * (Dropdown.clearMenus), which therefore never runs for clicks inside those tables.
 * Result: opening a second row's Actions dropdown leaves the first one open (overlap).
 *
 * This runs in the capture phase on document (before the table's listener) and closes
 * any open dropdown that does not contain the click target, mirroring clearMenus.
 */

const DROPDOWN_WRAPPER_SELECTOR = '.dropdown, .dropup, .dropstart, .dropend, .dropup-center, .dropdown-center, .btn-group';

function closeOtherDropdowns(event) {
  // Ignore right-clicks, same as Bootstrap
  if (event.button === 2) return;

  const target = event.target;
  if (!(target instanceof Element)) return;

  // Only needed where table-level handlers swallow the click
  if (!target.closest('table')) return;

  const bs = window.bootstrap;
  if (!bs || !bs.Dropdown) return;

  document.querySelectorAll('[data-bs-toggle="dropdown"].show').forEach((toggle) => {
    const wrapper = toggle.closest(DROPDOWN_WRAPPER_SELECTOR) || toggle.parentElement;

    // Click belongs to this dropdown (its toggle or menu): let Bootstrap handle it
    if (wrapper && wrapper.contains(target)) return;

    // Respect auto-close settings that keep the menu open on outside clicks
    const autoClose = toggle.getAttribute('data-bs-auto-close');
    if (autoClose === 'false' || autoClose === 'inside') return;

    const instance = bs.Dropdown.getInstance(toggle);
    if (instance) instance.hide();
  });
}

if (typeof document !== 'undefined' && !window.__datatableDropdownFixAttached) {
  window.__datatableDropdownFixAttached = true;
  document.addEventListener('click', closeOtherDropdowns, true);
}
