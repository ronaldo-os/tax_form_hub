/**
 * Action Spam Prevention
 * 
 * Protects against duplicate form submissions, action button spamming,
 * and rapid concurrent network requests across the application.
 */

const THROTTLE_WINDOW_MS = 400; // Minimum time between consecutive clicks on the same action element
const SAFETY_FALLBACK_TIMEOUT_MS = 6000; // Re-enable fallback if no response/navigation occurs

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
    button.textContent = disableWith;
  }

  button.classList.add('btn-submitting');
  button.setAttribute('aria-busy', 'true');
  button.style.pointerEvents = 'none';

  // Defer setting native .disabled = true via microtask/setTimeout
  // so browsers capture the button's name/value in the FormData before it is disabled
  setTimeout(() => {
    // Only apply if the form is still submitting
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
 * Sets up global form submission protection.
 */
function setupFormSubmitProtection() {
  // Capture phase: Intercept duplicate submissions immediately before any handler or Turbo runs
  document.addEventListener('submit', function (event) {
    const form = event.target.closest('form') || event.target;
    if (!form || form.tagName !== 'FORM') return;

    // If form is already submitting, drop this duplicate submit event
    if (form.dataset.submitting === 'true') {
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    // Mark as submitting synchronously to block any immediate subsequent submit events
    form.dataset.submitting = 'true';

    // Check if submission was prevented by client-side validation handlers after bubbling
    setTimeout(() => {
      if (event.defaultPrevented) {
        // Submission was stopped by custom JS or HTML5 validation; reset submitting state
        resetFormSubmitting(form);
        return;
      }

      // Submission is valid and active: disable buttons and set safety timeout
      const submitButtons = getFormSubmitButtons(form);
      submitButtons.forEach(disableButton);

      // Safety fallback: re-enable after timeout in case of file download or lost response
      if (form._submitTimeoutId) clearTimeout(form._submitTimeoutId);
      form._submitTimeoutId = setTimeout(() => {
        resetFormSubmitting(form);
      }, SAFETY_FALLBACK_TIMEOUT_MS);
    }, 0);
  }, true);

  // Turbo submit end event: re-enable buttons when Turbo finishes (success, redirect, or 422 error)
  document.addEventListener('turbo:submit-end', function (event) {
    const form = event.target;
    if (form && form.tagName === 'FORM') {
      resetFormSubmitting(form);
    } else {
      // Re-enable all forms on document if target is not specifically a form
      document.querySelectorAll('form[data-submitting="true"]').forEach(resetFormSubmitting);
    }
  });

  // Re-enable and reset on page lifecycle events
  const resetAllSubmissions = () => {
    document.querySelectorAll('form[data-submitting="true"]').forEach(resetFormSubmitting);
    document.querySelectorAll('.btn-submitting').forEach(restoreButton);
    document.querySelectorAll('a[data-action-in-flight="true"]').forEach(link => {
      link.dataset.actionInFlight = 'false';
      link.classList.remove('disabled');
      link.style.removeProperty('pointer-events');
    });
  };

  document.addEventListener('turbo:load', resetAllSubmissions);
  document.addEventListener('turbo:render', resetAllSubmissions);
  window.addEventListener('pageshow', resetAllSubmissions);
}

/**
 * Sets up action link and button click debouncing.
 */
function setupActionDebounce() {
  document.addEventListener('click', function (event) {
    // 1. Handle action links with turbo-method or method attributes (e.g., Delete links)
    const actionLink = event.target.closest('a[data-turbo-method], a[data-method]');
    if (actionLink) {
      if (actionLink.dataset.actionInFlight === 'true') {
        event.preventDefault();
        event.stopImmediatePropagation();
        return false;
      }

      actionLink.dataset.actionInFlight = 'true';
      actionLink.classList.add('disabled');
      actionLink.style.pointerEvents = 'none';

      setTimeout(() => {
        actionLink.dataset.actionInFlight = 'false';
        actionLink.classList.remove('disabled');
        actionLink.style.removeProperty('pointer-events');
      }, 2000);
      return;
    }

    // 2. Debounce rapid spam clicks on the same action button or submitter
    const actionBtn = event.target.closest('button, input[type="submit"], input[type="button"], .btn');
    if (!actionBtn) return;

    // Ignore text inputs, file inputs, checkboxes, radios
    if (['text', 'password', 'file', 'checkbox', 'radio'].includes(actionBtn.type)) return;

    const now = Date.now();
    const lastClick = parseInt(actionBtn.dataset.lastActionClick || '0', 10);

    if (now - lastClick < THROTTLE_WINDOW_MS) {
      // Rapid click detected on the exact same button - throttle it
      event.preventDefault();
      event.stopImmediatePropagation();
      return false;
    }

    actionBtn.dataset.lastActionClick = now.toString();
  }, true); // Capture phase to prevent duplicate handlers from firing
}

/**
 * Initializes action spam prevention.
 */
export function initActionSpamPrevention() {
  setupFormSubmitProtection();
  setupActionDebounce();
}

// Automatically initialize if loaded in browser
if (typeof document !== 'undefined') {
  initActionSpamPrevention();
}
