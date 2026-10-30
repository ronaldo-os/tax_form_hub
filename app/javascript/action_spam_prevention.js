/**
 * Action Spam Prevention
 *
 * Protects against duplicate form submissions, simultaneous clicks across
 * multiple action buttons, rapid page redirect clicks, and background XHR
 * contention during page transitions.
 */

const THROTTLE_WINDOW_MS = 400; // Minimum time between consecutive clicks on the same element
const GLOBAL_ACTION_COOLDOWN_MS = 300; // Minimum cooldown between clicking different action/redirect elements
const NAVIGATION_LOCK_MS = 1500; // Lock window preventing duplicate clicks on the same redirect URL
const SAFETY_FALLBACK_TIMEOUT_MS = 6000; // Re-enable fallback if no response/navigation occurs

let pageActionInFlight = false;
let pageActionTimeoutId = null;
let lastGlobalActionTimestamp = 0;
let navigationInFlightUrl = null;
let navigationTimeoutId = null;

const activeBackgroundXhrs = new Set();
const activeAbortControllers = new Set();

/**
 * Registers an AbortController for a background fetch request so it can be
 * cancelled automatically if the user triggers an action or page redirect.
 */
export function registerBackgroundFetchController(controller) {
  if (!controller) return;
  activeAbortControllers.add(controller);
}

export function unregisterBackgroundFetchController(controller) {
  if (!controller) return;
  activeAbortControllers.delete(controller);
}

/**
 * Aborts all in-flight non-mutating background XHR and fetch requests
 * (such as DataTables AJAX loads, chart refreshes, or preview fetches)
 * so they do not block Puma threads or browser connections during redirects.
 */
export function abortPendingBackgroundRequests() {
  activeBackgroundXhrs.forEach((jqXHR) => {
    try {
      if (jqXHR && typeof jqXHR.abort === 'function' && jqXHR.readyState !== 4) {
        jqXHR.abort();
      }
    } catch (e) {
      // Ignore abort errors
    }
  });
  activeBackgroundXhrs.clear();

  activeAbortControllers.forEach((controller) => {
    try {
      controller.abort();
    } catch (e) {
      // Ignore abort errors
    }
  });
  activeAbortControllers.clear();
}

/**
 * Closes any open Bootstrap dropdown menus so sibling action buttons inside
 * the same menu cannot be clicked simultaneously while an action is processing.
 */
function closeOpenDropdownMenus(originElement) {
  try {
    const dropdownMenu = originElement ? originElement.closest('.dropdown-menu') : null;
    const menusToClose = dropdownMenu
      ? [dropdownMenu]
      : Array.from(document.querySelectorAll('.dropdown-menu.show'));

    menusToClose.forEach((menu) => {
      const toggleBtn = menu.parentElement?.querySelector('[data-bs-toggle="dropdown"]');
      if (toggleBtn && typeof bootstrap !== 'undefined' && bootstrap.Dropdown) {
        const instance = bootstrap.Dropdown.getInstance(toggleBtn);
        if (instance) {
          instance.hide();
          return;
        }
      }
      menu.classList.remove('show');
      if (toggleBtn) {
        toggleBtn.classList.remove('show');
        toggleBtn.setAttribute('aria-expanded', 'false');
      }
    });
  } catch (e) {
    // Ignore dropdown close errors
  }
}

/**
 * Sets or clears the page-level mutating action lock.
 */
function setPageActionInFlight(inFlight) {
  pageActionInFlight = Boolean(inFlight);
  if (pageActionTimeoutId) {
    clearTimeout(pageActionTimeoutId);
    pageActionTimeoutId = null;
  }

  if (pageActionInFlight) {
    if (document.body) {
      document.body.dataset.actionInFlight = 'true';
    }
    pageActionTimeoutId = setTimeout(() => {
      pageActionInFlight = false;
      if (document.body) {
        delete document.body.dataset.actionInFlight;
      }
    }, SAFETY_FALLBACK_TIMEOUT_MS);
  } else if (document.body) {
    delete document.body.dataset.actionInFlight;
  }
}

/**
 * Re-enables a button and restores any preserved attributes or text.
 */
function restoreButton(button) {
  if (!button) return;

  button.disabled = false;
  button.classList.remove('btn-submitting', 'disabled');
  button.removeAttribute('aria-busy');
  button.style.removeProperty('pointer-events');

  if (button.dataset.originalHtml !== undefined) {
    button.innerHTML = button.dataset.originalHtml;
    delete button.dataset.originalHtml;
  }
}

/**
 * Disables a button and applies submitting visual indicators.
 */
function disableButton(button) {
  if (!button) return;

  // Save original HTML if data-disable-with is specified
  const disableWith = button.getAttribute('data-disable-with');
  if (disableWith && button.dataset.originalHtml === undefined) {
    button.dataset.originalHtml = button.innerHTML;
    if (disableWith.includes('<')) {
      button.innerHTML = disableWith;
    } else {
      button.textContent = disableWith;
    }
  }

  button.classList.add('btn-submitting');
  button.setAttribute('aria-busy', 'true');
  button.style.pointerEvents = 'none';

  // Defer setting native .disabled = true via microtask/setTimeout
  // so browsers and Turbo capture the button's name/value in FormData first
  setTimeout(() => {
    const form = button.form || button.closest('form');
    if (!form || form.dataset.submitting === 'true') {
      button.disabled = true;
    }
  }, 0);
}

/**
 * Resets all submit buttons for a given form.
 */
export function resetFormSubmitting(form) {
  if (!form) return;

  form.dataset.submitting = 'false';
  form.dataset.turboSubmitStarted = 'false';
  form.dataset.confirming = 'false';

  const buttons = getFormSubmitButtons(form);
  buttons.forEach(restoreButton);

  if (form._submitTimeoutId) {
    clearTimeout(form._submitTimeoutId);
    delete form._submitTimeoutId;
  }
}

/**
 * Collects all submit buttons associated with a form.
 */
function getFormSubmitButtons(form) {
  const buttons = new Set();

  form.querySelectorAll('button[type="submit"], input[type="submit"], button:not([type])').forEach(btn => {
    buttons.add(btn);
  });

  if (form.id) {
    try {
      document.querySelectorAll(`button[form="${CSS.escape(form.id)}"], input[form="${CSS.escape(form.id)}"]`).forEach(btn => {
        buttons.add(btn);
      });
    } catch (e) {
      // In case form.id contains unusual characters
    }
  }

  return Array.from(buttons);
}

/**
 * Resets all active submission and navigation locks across the document.
 */
export function resetAllSubmissions() {
  setPageActionInFlight(false);
  navigationInFlightUrl = null;
  if (navigationTimeoutId) {
    clearTimeout(navigationTimeoutId);
    navigationTimeoutId = null;
  }

  document.querySelectorAll('form[data-submitting="true"], form[data-confirming="true"]').forEach(resetFormSubmitting);
  document.querySelectorAll('.btn-submitting').forEach(restoreButton);
  document.querySelectorAll('a[data-action-in-flight="true"], a[data-redirect-in-flight="true"]').forEach(link => {
    link.dataset.actionInFlight = 'false';
    link.dataset.redirectInFlight = 'false';
    link.classList.remove('disabled', 'btn-submitting');
    link.style.removeProperty('pointer-events');
  });
}

/**
 * Sets up jQuery AJAX tracking so background GET requests can be aborted on navigation/action.
 */
function setupBackgroundAjaxTracking() {
  const attachJqueryHooks = () => {
    if (typeof window.$ === 'undefined' || !window.$.fn || window._ajaxSpamHooksAttached) return false;
    window._ajaxSpamHooksAttached = true;

    window.$(document).on('ajaxSend', function (_event, jqXHR, settings) {
      const type = ((settings && settings.type) || 'GET').toUpperCase();
      if (type === 'GET') {
        activeBackgroundXhrs.add(jqXHR);
      }
    });

    window.$(document).on('ajaxComplete', function (_event, jqXHR) {
      activeBackgroundXhrs.delete(jqXHR);
    });

    return true;
  };

  if (!attachJqueryHooks()) {
    document.addEventListener('DOMContentLoaded', attachJqueryHooks, { once: true });
    document.addEventListener('turbo:load', attachJqueryHooks, { once: true });
  }
}

/**
 * Sets up global form submission protection.
 */
function setupFormSubmitProtection() {
  // Capture phase: Intercept duplicate or concurrent submissions immediately before any handler or Turbo runs
  document.addEventListener('submit', function (event) {
    const form = event.target.closest('form') || event.target;
    if (!form || form.tagName !== 'FORM') return;

    const method = (form.getAttribute('method') || 'get').toLowerCase();
    const isGetForm = method === 'get' && !form.querySelector('input[name="_method"]');

    // If this form or another page-level mutating action is already submitting, block duplicate/concurrent submit
    if (form.dataset.submitting === 'true' || (!isGetForm && pageActionInFlight)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    const submitter = event.submitter || document.activeElement;
    const hasConfirm = Boolean(
      form.hasAttribute('data-turbo-confirm') ||
      form.hasAttribute('data-confirm') ||
      (submitter && (submitter.hasAttribute?.('data-turbo-confirm') || submitter.hasAttribute?.('data-confirm')))
    );

    form.dataset.submitting = 'true';
    form.dataset.turboSubmitStarted = 'false';
    form.dataset.confirming = hasConfirm ? 'true' : 'false';

    closeOpenDropdownMenus(submitter || form);

    if (hasConfirm) {
      // Wait for confirmation modal resolution; if cancelled, resetFormSubmitting will be called
      if (form._submitTimeoutId) clearTimeout(form._submitTimeoutId);
      form._submitTimeoutId = setTimeout(() => {
        if (form.dataset.turboSubmitStarted !== 'true') {
          resetFormSubmitting(form);
        }
      }, SAFETY_FALLBACK_TIMEOUT_MS);
      return;
    }

    if (!isGetForm) {
      setPageActionInFlight(true);
      abortPendingBackgroundRequests();
    }

    // Check after event bubbling whether custom client-side validation prevented submission.
    // Note: Turbo Drive also calls event.preventDefault() when it takes over a form submission,
    // but Turbo immediately fires `turbo:submit-start` (or `turbo:before-fetch-request`).
    setTimeout(() => {
      const isTurboManaged = form.dataset.turbo !== 'false' && typeof window.Turbo !== 'undefined';
      const wasStoppedByClientValidation =
        event.defaultPrevented &&
        (!isTurboManaged || form.dataset.turboSubmitStarted !== 'true');

      if (wasStoppedByClientValidation) {
        resetFormSubmitting(form);
        if (!isGetForm) {
          setPageActionInFlight(false);
        }
        return;
      }

      // Submission is active: disable buttons and arm safety fallback timeout
      const submitButtons = getFormSubmitButtons(form);
      submitButtons.forEach(disableButton);

      if (form._submitTimeoutId) clearTimeout(form._submitTimeoutId);
      form._submitTimeoutId = setTimeout(() => {
        resetFormSubmitting(form);
        if (!isGetForm) {
          setPageActionInFlight(false);
        }
      }, SAFETY_FALLBACK_TIMEOUT_MS);
    }, 30);
  }, true);

  // Turbo form submission start (fires after any data-turbo-confirm dialog is accepted)
  document.addEventListener('turbo:submit-start', function (event) {
    const form = event.target;
    if (!form || form.tagName !== 'FORM') return;

    form.dataset.turboSubmitStarted = 'true';
    form.dataset.confirming = 'false';
    form.dataset.submitting = 'true';

    setPageActionInFlight(true);
    abortPendingBackgroundRequests();
    closeOpenDropdownMenus(form);

    const submitButtons = getFormSubmitButtons(form);
    submitButtons.forEach(disableButton);

    if (form._submitTimeoutId) clearTimeout(form._submitTimeoutId);
    form._submitTimeoutId = setTimeout(() => {
      resetFormSubmitting(form);
      setPageActionInFlight(false);
    }, SAFETY_FALLBACK_TIMEOUT_MS);
  }, true);

  // Turbo submit end event: re-enable buttons when Turbo finishes (e.g. 422 validation error or stream update)
  document.addEventListener('turbo:submit-end', function (event) {
    const form = event.target;
    const fetchResponse = event.detail?.fetchResponse;
    const isRedirecting = Boolean(fetchResponse && fetchResponse.redirected);

    // If the response is a redirect, keep the action lock active briefly until Turbo renders the redirected page
    if (isRedirecting) {
      setTimeout(() => {
        if (form && form.tagName === 'FORM') {
          resetFormSubmitting(form);
        }
        setPageActionInFlight(false);
      }, 600);
      return;
    }

    setPageActionInFlight(false);
    if (form && form.tagName === 'FORM') {
      resetFormSubmitting(form);
    } else {
      document.querySelectorAll('form[data-submitting="true"]').forEach(resetFormSubmitting);
    }
  });

  // Track non-GET Turbo fetch requests (such as a[data-turbo-method="patch|delete|post"])
  document.addEventListener('turbo:before-fetch-request', function (event) {
    const method = (event.detail?.fetchOptions?.method || 'GET').toUpperCase();
    if (method !== 'GET') {
      setPageActionInFlight(true);
      abortPendingBackgroundRequests();
    }
  });

  document.addEventListener('turbo:fetch-request-error', function () {
    resetAllSubmissions();
  });

  // Abort pending background XHR/fetch requests whenever Turbo begins visiting a new page
  document.addEventListener('turbo:before-visit', function () {
    abortPendingBackgroundRequests();
  });

  document.addEventListener('turbo:load', resetAllSubmissions);
  document.addEventListener('turbo:render', resetAllSubmissions);
  window.addEventListener('pageshow', resetAllSubmissions);
}

/**
 * Sets up action link, action button, and page redirect click coordination.
 */
function setupActionDebounce() {
  document.addEventListener('click', function (event) {
    // Allow clicks inside the confirmation modal (#turboConfirmModal) to resolve normally,
    // while preventing double-clicks on its Accept/Cancel buttons.
    const confirmModalBtn = event.target.closest('#turboConfirmAccept, #turboConfirmCancel');
    if (confirmModalBtn) {
      const now = Date.now();
      const lastClick = parseInt(confirmModalBtn.dataset.lastActionClick || '0', 10);
      if (now - lastClick < THROTTLE_WINDOW_MS) {
        event.preventDefault();
        event.stopImmediatePropagation();
        return false;
      }
      confirmModalBtn.dataset.lastActionClick = now.toString();
      if (confirmModalBtn.id === 'turboConfirmCancel') {
        setTimeout(resetAllSubmissions, 0);
      }
      return;
    }

    // 1. Handle mutating action links with turbo-method or method attributes (e.g. Approve, Reject, Mark Paid, Archive, Delete)
    const actionLink = event.target.closest('a[data-turbo-method], a[data-method]');
    if (actionLink) {
      if (actionLink.dataset.actionInFlight === 'true' || pageActionInFlight) {
        event.preventDefault();
        event.stopImmediatePropagation();
        return false;
      }

      const now = Date.now();
      const lastClick = parseInt(actionLink.dataset.lastActionClick || '0', 10);
      if (now - lastClick < THROTTLE_WINDOW_MS) {
        event.preventDefault();
        event.stopImmediatePropagation();
        return false;
      }
      actionLink.dataset.lastActionClick = now.toString();

      closeOpenDropdownMenus(actionLink);

      const hasConfirm = actionLink.hasAttribute('data-turbo-confirm') || actionLink.hasAttribute('data-confirm');
      if (!hasConfirm) {
        actionLink.dataset.actionInFlight = 'true';
        actionLink.classList.add('disabled', 'btn-submitting');
        actionLink.style.pointerEvents = 'none';
        setPageActionInFlight(true);
        abortPendingBackgroundRequests();

        setTimeout(() => {
          actionLink.dataset.actionInFlight = 'false';
          actionLink.classList.remove('disabled', 'btn-submitting');
          actionLink.style.removeProperty('pointer-events');
        }, SAFETY_FALLBACK_TIMEOUT_MS);
      }
      return;
    }

    // 2. Handle page redirect / navigation links (a[href])
    const navLink = event.target.closest('a[href]');
    if (navLink) {
      // Ignore modified clicks (new tab/window)
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return;

      const rawHref = navLink.getAttribute('href') || '';
      const isUiToggle =
        !rawHref ||
        rawHref === '#' ||
        rawHref.startsWith('#') ||
        rawHref.startsWith('javascript:') ||
        navLink.hasAttribute('data-bs-toggle') ||
        navLink.hasAttribute('data-bs-dismiss') ||
        navLink.hasAttribute('download') ||
        navLink.getAttribute('target') === '_blank' ||
        navLink.getAttribute('data-remote') === 'true' ||
        navLink.classList.contains('preview-invoice') ||
        navLink.classList.contains('download-pdf');

      if (!isUiToggle) {
        // If a mutating form/action is currently in flight, block simultaneous redirect clicks
        // so the browser does not queue competing requests against the server redirect.
        if (pageActionInFlight) {
          event.preventDefault();
          event.stopImmediatePropagation();
          return false;
        }

        const now = Date.now();
        const lastLinkClick = parseInt(navLink.dataset.lastActionClick || '0', 10);
        const targetUrl = navLink.href;

        // Block rapid duplicate clicks on the same redirect link or back button
        if (
          now - lastLinkClick < THROTTLE_WINDOW_MS ||
          navLink.dataset.redirectInFlight === 'true' ||
          (navigationInFlightUrl && navigationInFlightUrl === targetUrl && now - lastGlobalActionTimestamp < NAVIGATION_LOCK_MS)
        ) {
          event.preventDefault();
          event.stopImmediatePropagation();
          return false;
        }

        // Throttle simultaneous clicks across different redirect links within the cooldown window
        if (now - lastGlobalActionTimestamp < GLOBAL_ACTION_COOLDOWN_MS && navigationInFlightUrl) {
          event.preventDefault();
          event.stopImmediatePropagation();
          return false;
        }

        navLink.dataset.lastActionClick = now.toString();
        lastGlobalActionTimestamp = now;
        navigationInFlightUrl = targetUrl;

        if (navLink.classList.contains('btn-back') || navLink.getAttribute('data-behavior') === 'back-button') {
          navLink.dataset.redirectInFlight = 'true';
        }

        closeOpenDropdownMenus(navLink);
        abortPendingBackgroundRequests();

        if (navigationTimeoutId) clearTimeout(navigationTimeoutId);
        navigationTimeoutId = setTimeout(() => {
          navigationInFlightUrl = null;
          navLink.dataset.redirectInFlight = 'false';
        }, NAVIGATION_LOCK_MS);

        return;
      }
    }

    // 3. Debounce rapid or simultaneous clicks on action buttons / submitters
    const actionBtn = event.target.closest('button, input[type="submit"], input[type="button"], .btn');
    if (!actionBtn) return;

    // Ignore text inputs, file inputs, checkboxes, radios
    if (['text', 'password', 'file', 'checkbox', 'radio'].includes(actionBtn.type)) return;

    const isUiOnlyBtn =
      actionBtn.hasAttribute('data-bs-toggle') ||
      actionBtn.hasAttribute('data-bs-dismiss') ||
      actionBtn.classList.contains('accordion-button') ||
      actionBtn.classList.contains('nav-link') ||
      actionBtn.classList.contains('clear-selection-btn');

    // If a mutating server action is already in flight, block clicking other submit/action buttons
    if (pageActionInFlight && !isUiOnlyBtn) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    const now = Date.now();
    const lastClick = parseInt(actionBtn.dataset.lastActionClick || '0', 10);

    if (now - lastClick < THROTTLE_WINDOW_MS) {
      // Rapid click detected on the exact same button - throttle it
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    // Also prevent clicking two different submit buttons simultaneously within the global cooldown
    const isSubmitBtn =
      actionBtn.type === 'submit' ||
      (!actionBtn.type && actionBtn.tagName === 'BUTTON' && Boolean(actionBtn.closest('form')));

    if (isSubmitBtn && now - lastGlobalActionTimestamp < GLOBAL_ACTION_COOLDOWN_MS) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    actionBtn.dataset.lastActionClick = now.toString();
    if (!isUiOnlyBtn) {
      lastGlobalActionTimestamp = now;
    }
  }, true); // Capture phase to prevent duplicate handlers from firing
}

/**
 * Initializes action spam prevention.
 */
export function initActionSpamPrevention() {
  if (typeof document !== 'undefined' && document._actionSpamPreventionInitialized) {
    return;
  }
  if (typeof document !== 'undefined') {
    document._actionSpamPreventionInitialized = true;
  }
  setupBackgroundAjaxTracking();
  setupFormSubmitProtection();
  setupActionDebounce();
}

// Automatically initialize if loaded in browser
if (typeof document !== 'undefined') {
  initActionSpamPrevention();
}
