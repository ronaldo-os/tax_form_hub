// Lazy load page-specific modules to reduce initial bundle size
// Each module is dynamically imported only when needed based on the current path
function loadPageSpecificModules() {
  const path = window.location.pathname;

  // Use dynamic imports with webpack/esbuild magic comments for chunk naming
  if (path.includes('/invoices')) {
    if (path.match(/\/invoices\/?$/)) {
      import(/* webpackChunkName: "index_invoice" */ './index_invoice');
    } else if (path.match(/\/invoices\/new/) || path.match(/\/invoices\/\d+\/edit/)) {
      import(/* webpackChunkName: "invoice" */ './invoice');
    } else if (path.match(/\/invoices\/\d+$/)) {
      import(/* webpackChunkName: "view_invoice" */ './view_invoice');
    }
  }

  if (path === '/' || path.includes('/dashboard')) {
    import(/* webpackChunkName: "dashboard" */ './dashboard').then(module => {
      if (module && typeof module.initAnalyticsDashboard === 'function') {
        module.initAnalyticsDashboard();
      }
    }).catch(err => console.error('[Dashboard] Failed to load module:', err));
  }

  if (path.includes('/tax_submissions')) {
    import(/* webpackChunkName: "client_submissions" */ './client_submissions');
    import(/* webpackChunkName: "admin_client_submissions" */ './admin_client_submissions');
  }

  if (path.includes('/admin')) {
    import(/* webpackChunkName: "admin_client_submissions" */ './admin_client_submissions');
  }

  if (path.includes('/locations')) {
    import(/* webpackChunkName: "locations" */ './locations');
  }

  if (path.includes('/subscriptions')) {
    import(/* webpackChunkName: "subscriptions" */ './subscriptions');
  }

  if (path.includes('/companies')) {
    import(/* webpackChunkName: "companies" */ './companies');
  }


  if (path.includes('/profile/edit') || path.includes('/edit_profile') || path.includes('/users/edit')) {
    import(/* webpackChunkName: "edit_profile" */ './edit_profile');
  }
}

// Always load network search (small utility)
import './network_search';

// Ensure any legacy service workers are unregistered on load.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async () => {
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      console.log('[PWA] Unregistering service worker:', registration.scope);
      await registration.unregister();
    }
  });
}

import Rails from "@rails/ujs";
import "@hotwired/turbo-rails";
import { Turbo } from "@hotwired/turbo-rails";

window.isInvoiceFormDirty = false;
window.isNavigatingConfirmed = false;

window.showUnsavedChangesModal = function ({
  title = "Unsaved Changes",
  message = "You have unsaved changes. If you continue, your changes will be lost. Are you sure you want to proceed?",
  confirmText = "Continue"
} = {}) {
  return new Promise((resolve) => {
    // Remove any leftover modal elements or backdrops
    const existingModal = document.getElementById('turboConfirmModal');
    if (existingModal) {
      existingModal.remove();
    }
    document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
    document.body.classList.remove('modal-open');
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('padding-right');

    const modalHtml = `
      <div class="modal fade" id="turboConfirmModal" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">${title}</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <p class="mb-0">${message}</p>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal" id="turboConfirmCancel">Cancel</button>
              <button type="button" class="btn btn-danger" id="turboConfirmAccept">${confirmText}</button>
            </div>
          </div>
        </div>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHtml);

    const modalElement = document.getElementById('turboConfirmModal');
    let resolved = false;

    function cleanupModal() {
      if (modalElement && modalElement.parentNode) {
        modalElement.remove();
      }
      document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
      document.body.classList.remove('modal-open');
      document.body.style.removeProperty('overflow');
      document.body.style.removeProperty('padding-right');
    }

    // Fallback if bootstrap is undefined or missing
    if (typeof bootstrap === 'undefined' || !bootstrap.Modal) {
      console.warn("Bootstrap not found, falling back to native confirm");
      const userConfirmed = window.confirm(message);
      if (userConfirmed) {
        window.isInvoiceFormDirty = false;
        window.isNavigatingConfirmed = true;
      }
      cleanupModal();
      resolve(userConfirmed);
      return;
    }

    let modal;
    try {
      modal = new bootstrap.Modal(modalElement);
    } catch (e) {
      console.error(e);
      const userConfirmed = window.confirm(message);
      if (userConfirmed) {
        window.isInvoiceFormDirty = false;
        window.isNavigatingConfirmed = true;
      }
      cleanupModal();
      resolve(userConfirmed);
      return;
    }

    const acceptBtn = document.getElementById('turboConfirmAccept');
    if (acceptBtn) {
      acceptBtn.addEventListener('click', () => {
        if (!resolved) {
          resolved = true;
          window.isInvoiceFormDirty = false;
          window.isNavigatingConfirmed = true;
          try { modal.hide(); } catch (e) {}
          cleanupModal();
          resolve(true);
        }
      });
    }

    const cancelBtn = document.getElementById('turboConfirmCancel');
    if (cancelBtn) {
      cancelBtn.addEventListener('click', () => {
        if (!resolved) {
          resolved = true;
          window.isNavigatingConfirmed = false;
          try { modal.hide(); } catch (e) {}
          cleanupModal();
          resolve(false);
        }
      });
    }

    modalElement.addEventListener('hidden.bs.modal', () => {
      cleanupModal();
      if (!resolved) {
        resolved = true;
        window.isNavigatingConfirmed = false;
        resolve(false);
      }
    });

    modal.show();
  });
};

const handleCustomConfirm = (message, element) => {
  let finalMessage = message;
  let title = "Confirmation";
  let confirmText = "OK";

  let isLogout = false;
  let isDiscard = false;

  try {
    if (element) {
      isLogout = element.id === 'logout-btn' ||
        element.id === 'mobile-logout-btn' ||
        (typeof element.closest === 'function' && element.closest('#logout-btn, #mobile-logout-btn') !== null) ||
        message.toLowerCase().includes('log out');

      isDiscard = element.classList?.contains('discard-btn') ||
        element.classList?.contains('discard-form') ||
        (typeof element.closest === 'function' && (element.closest('.discard-btn') !== null || element.closest('.discard-form') !== null)) ||
        message.toLowerCase().includes('discard');
    } else {
      isLogout = message.toLowerCase().includes('log out');
      isDiscard = message.toLowerCase().includes('discard');
    }
  } catch (e) {
    console.error(e);
  }

  if (window.isInvoiceFormDirty && (isLogout || isDiscard)) {
    title = "Unsaved Changes";
    finalMessage = "You have unsaved changes. If you continue, your changes will be lost. Are you sure you want to proceed?";
    confirmText = isLogout ? "Continue" : "Discard";
  }

  return window.showUnsavedChangesModal({ title, message: finalMessage, confirmText });
};

if (typeof Turbo !== "undefined" && Turbo.setConfirmMethod) {
  Turbo.setConfirmMethod(handleCustomConfirm);
}
if (typeof Turbo !== "undefined" && Turbo.config && Turbo.config.forms) {
  Turbo.config.forms.confirm = handleCustomConfirm;
}

// Intercept Turbo navigation when form contains unsaved changes
document.addEventListener("turbo:before-visit", (event) => {
  if (window.isInvoiceFormDirty && !window.isNavigatingConfirmed) {
    event.preventDefault();
    const targetUrl = event.detail.url;
    const action = event.detail.action || "advance";
    const currentUrl = window.location.href;

    window.showUnsavedChangesModal({
      title: "Unsaved Changes",
      message: "You have unsaved changes. If you continue, your changes will be lost. Are you sure you want to proceed?",
      confirmText: "Continue"
    }).then((confirmed) => {
      if (confirmed) {
        window.isInvoiceFormDirty = false;
        window.isNavigatingConfirmed = true;
        if (typeof Turbo !== "undefined" && Turbo.visit) {
          Turbo.visit(targetUrl, { action });
        } else {
          window.location.href = (typeof targetUrl === "string") ? targetUrl : targetUrl.href;
        }
      } else {
        window.isNavigatingConfirmed = false;
        if (window.location.href !== currentUrl) {
          window.history.pushState(null, '', currentUrl);
        }
      }
    });
  }
});

// Intercept non-Turbo internal link clicks when form is dirty
document.addEventListener("click", (event) => {
  if (!window.isInvoiceFormDirty || window.isNavigatingConfirmed) return;

  const link = event.target.closest("a[href]");
  if (!link) return;

  if (link.dataset.turboConfirm || link.getAttribute("data-turbo-confirm")) return;

  const href = link.getAttribute("href");
  if (!href || href === "#" || href.startsWith("javascript:") || href.startsWith("#")) return;
  if (link.dataset.bsToggle || link.dataset.bsDismiss) return;
  if (link.target === "_blank") return;

  if (link.dataset.turbo === "false") {
    event.preventDefault();
    window.showUnsavedChangesModal({
      title: "Unsaved Changes",
      message: "You have unsaved changes. If you continue, your changes will be lost. Are you sure you want to proceed?",
      confirmText: "Continue"
    }).then((confirmed) => {
      if (confirmed) {
        window.isInvoiceFormDirty = false;
        window.isNavigatingConfirmed = true;
        window.location.href = link.href;
      } else {
        window.isNavigatingConfirmed = false;
      }
    });
  }
}, true);

// Browser tab reload / close / external navigation alert
window.addEventListener("beforeunload", (event) => {
  if (window.isInvoiceFormDirty && !window.isNavigatingConfirmed) {
    event.preventDefault();
    event.returnValue = "";
    return "";
  }
});

import { Application } from "@hotwired/stimulus";
Rails.start();

// Initialize Stimulus application
const stimulusApplication = Application.start();

// Configure Stimulus
stimulusApplication.debug = false;

// Import Stimulus controllers explicitly (import.meta.glob not supported by esbuild)
import EmailValidationController from './controllers/email_validation_controller';
import LazyLoaderController from './controllers/lazy_loader_controller';
import PasswordToggleController from './controllers/password_toggle_controller';
import SidebarController from './controllers/sidebar_controller';
import PasswordValidationController from './controllers/password_validation_controller';
import NotificationsController from './controllers/notifications_controller';

// Register all controllers
stimulusApplication.register('email-validation', EmailValidationController);
stimulusApplication.register('lazy-loader', LazyLoaderController);
stimulusApplication.register('password-toggle', PasswordToggleController);
stimulusApplication.register('sidebar', SidebarController);
stimulusApplication.register('password-validation', PasswordValidationController);
stimulusApplication.register('notifications', NotificationsController);

// Observer for live toast notifications inserted via Turbo Streams
function observeLiveToasts() {
  const container = document.getElementById('live_notification_toasts');
  if (!container) return;

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === 1 && node.classList.contains('live-notification-toast')) {
          if (typeof bootstrap !== 'undefined' && bootstrap.Toast) {
            const bsToast = new bootstrap.Toast(node, { delay: 7000, autohide: true });
            bsToast.show();
          }
        }
      });
    });
  });

  observer.observe(container, { childList: true });
}

document.addEventListener('DOMContentLoaded', observeLiveToasts);
document.addEventListener('turbo:load', observeLiveToasts);

function updateThemeUI(theme) {
  const btns = [
    document.getElementById('theme_toggle_btn'),
    document.getElementById('header_theme_toggle_btn')
  ];

  btns.forEach(btn => {
    if (!btn) return;
    const icon = btn.querySelector('i');
    const text = btn.querySelector('.app-text');

    if (theme === 'dark') {
      if (icon) {
        icon.classList.remove('fa-moon');
        icon.classList.add('fa-sun');
      }
      if (text) text.textContent = 'Light Mode';
    } else {
      if (icon) {
        icon.classList.remove('fa-sun');
        icon.classList.add('fa-moon');
      }
      if (text) text.textContent = 'Dark Mode';
    }
  });
}

function handleThemeToggle(e) {
  e.preventDefault();
  const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
  const newTheme = currentTheme === 'light' ? 'dark' : 'light';

  console.log('Theme toggle clicked. Current:', currentTheme, 'New:', newTheme);

  // Disable transitions temporarily
  const css = document.createElement('style');
  css.appendChild(
    document.createTextNode(
      `* {
               -webkit-transition: none !important;
               -moz-transition: none !important;
               -o-transition: none !important;
               -ms-transition: none !important;
               transition: none !important;
            }`
    )
  );
  document.head.appendChild(css);

  document.documentElement.setAttribute('data-theme', newTheme);
  document.documentElement.setAttribute('data-bs-theme', newTheme);

  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
  if (csrfToken) {
    fetch('/profile/theme', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ theme: newTheme })
    }).catch(err => console.error('Failed to save theme:', err));
  }

  updateThemeUI(newTheme);

  // Update dynamic elements that don't automatically respond to theme changes
  updateDynamicElementsForTheme(newTheme);

  // Dispatch custom event to notify components of theme change
  const event = new CustomEvent('theme:changed', { detail: { theme: newTheme } });
  document.dispatchEvent(event);

  // Force repaint before re-enabling transitions
  const _ = window.getComputedStyle(css).opacity;
  document.head.removeChild(css);
}

function updateDynamicElementsForTheme(theme) {
  // Update all badges that use theme-dependent classes (both subtle and solid)
  const allBadges = document.querySelectorAll('.badge.bg-primary-subtle, .badge.bg-primary, .badge.bg-success-subtle, .badge.bg-success, .badge.bg-danger-subtle, .badge.bg-danger, .badge.bg-info-subtle, .badge.bg-info');
  allBadges.forEach(badge => {
    if (theme === 'dark') {
      // Convert to solid colors in dark mode
      if (badge.classList.contains('bg-primary-subtle')) {
        badge.classList.remove('bg-primary-subtle', 'text-primary');
        badge.classList.add('bg-primary', 'text-white');
      }
      if (badge.classList.contains('bg-success-subtle')) {
        badge.classList.remove('bg-success-subtle', 'text-success-emphasis', 'text-success');
        badge.classList.add('bg-success', 'text-white');
      }
      if (badge.classList.contains('bg-danger-subtle')) {
        badge.classList.remove('bg-danger-subtle', 'text-danger');
        badge.classList.add('bg-danger', 'text-white');
      }
      if (badge.classList.contains('bg-info-subtle')) {
        badge.classList.remove('bg-info-subtle', 'text-info');
        badge.classList.add('bg-info', 'text-white');
      }
    } else {
      // Convert back to subtle colors in light mode
      if (badge.classList.contains('bg-primary')) {
        badge.classList.remove('bg-primary', 'text-white');
        badge.classList.add('bg-primary-subtle', 'text-primary');
      }
      if (badge.classList.contains('bg-success')) {
        badge.classList.remove('bg-success', 'text-white');
        badge.classList.add('bg-success-subtle', 'text-success-emphasis');
      }
      if (badge.classList.contains('bg-danger')) {
        badge.classList.remove('bg-danger', 'text-white');
        badge.classList.add('bg-danger-subtle', 'text-danger');
      }
      if (badge.classList.contains('bg-info')) {
        badge.classList.remove('bg-info', 'text-white');
        badge.classList.add('bg-info-subtle', 'text-info');
      }
    }
  });

  // Update DataTables if they exist
  if (typeof $ !== 'undefined' && $.fn.DataTable) {
    $('.dataTable').each(function () {
      const dt = $(this).DataTable();
      // Redraw without resetting paging to apply new theme styles
      dt.draw(false);
    });

    // Update DataTable pagination and info elements
    $('.dataTables_wrapper .dataTables_info, .dataTables_wrapper .dataTables_paginate').each(function () {
      this.style.color = 'var(--text-main)';
    });
  }

  // Force form controls to recalculate their styles
  const formControls = document.querySelectorAll('.form-control, .form-select');
  formControls.forEach(control => {
    // Temporarily remove and re-add the class to force style recalculation
    const className = control.className;
    control.className = '';
    control.className = className;
  });

  // Specifically handle file inputs in modals
  const modalFileInputs = document.querySelectorAll('.modal .file-upload-input, .modal input[type="file"]');
  modalFileInputs.forEach(input => {
    // Force style recalculation for file inputs
    const className = input.className;
    input.className = '';
    input.className = className;

    // Also update the file selector button style if it exists
    if (input.style) {
      input.style.backgroundColor = '';
      input.style.color = '';
      input.style.borderColor = '';
    }
  });
}

// Event delegation handler for theme toggle clicks
function handleThemeToggleEvent(e) {
  const themeBtn = e.target.closest('#theme_toggle_btn, #header_theme_toggle_btn');
  if (themeBtn) {
    handleThemeToggle(e);
  }
}

function initApplication() {
  // Theme Toggle Logic - Ensure theme is synced from server rendering
  const metaTheme = document.querySelector('meta[name="user-theme"]')?.getAttribute('content');
  const savedTheme = metaTheme || document.documentElement.getAttribute('data-theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  document.documentElement.setAttribute('data-bs-theme', savedTheme);

  // Initial UI update
  updateThemeUI(savedTheme);

  // Initialize dynamic elements for current theme
  updateDynamicElementsForTheme(savedTheme);

  // Setup theme toggle button listener using vanilla JS event delegation
  document.removeEventListener('click', handleThemeToggleEvent);
  document.addEventListener('click', handleThemeToggleEvent);

  // password toggle handler - delegated event
  $(document).off('click.pw-toggle').on('click.pw-toggle', '.toggle-password-icon, .input-group-text', function (event) {
    const $wrapper = $(this);
    const $icon = $wrapper.is('.toggle-password-icon') ? $wrapper : $wrapper.find('.toggle-password-icon');
    if (!$icon.length) return;

    // If the click originated from an icon inside an input-group-text, ignore the icon event and let the input-group-text handle it to prevent double-firing
    if ($wrapper.is('.toggle-password-icon') && $wrapper.closest('.input-group-text').length) {
      return;
    }

    event.preventDefault();

    const $inputGroup = $wrapper.closest('.input-group');
    const $input = $inputGroup.find('input[type="password"], input[type="text"].toggle-password-input, input[name*="password"]').first();

    if ($input.length) {
      if ($input.attr('type') === 'password') {
        $input.attr('type', 'text');
        $icon.removeClass('fa-eye').addClass('fa-eye-slash');
      } else {
        $input.attr('type', 'password');
        $icon.removeClass('fa-eye-slash').addClass('fa-eye');
      }
    }
  });

  // Sidenav toggle function 
  const $menuToggle = $("#desktop_menu_toggle");
  const $mobileToggle = $("#mobile_menu_toggle");
  const $mobileClose = $("#mobile_menu_close");
  const $sidebar = $(".app-sidebar");
  const $body = $("body");
  // Exclude the theme toggle button from the menu list items
  const $menuListItems = $(".app-menu-list li").not("#theme_toggle_btn");

  // Remove existing handlers to prevent duplicate binding
  $menuToggle.off("click");
  $mobileToggle.off("click");
  $mobileClose.off("click");
  $menuListItems.off("click");
  $(document).off("keyup.sidebar");

  // === Desktop toggle ===
  $menuToggle.on("click", function () {
    $menuToggle.toggleClass("app-active");
    $sidebar.toggleClass("app-active");
  });

  // === Mobile toggle ===
  $mobileToggle.on("click", function () {
    $mobileToggle.toggleClass("app-active");
    $sidebar.toggleClass("app-active");
    $body.toggleClass("mobile-menu-open", $sidebar.hasClass("app-active"));
  });

  // === Mobile close button ===
  $mobileClose.on("click", function () {
    $sidebar.removeClass("app-active");
    $mobileToggle.removeClass("app-active");
    $body.removeClass("mobile-menu-open");
  });

  // === Escape key to close mobile sidebar ===
  $(document).on("keyup.sidebar", function (e) {
    if (e.key === "Escape" && $sidebar.hasClass("app-active") && window.innerWidth <= 991.98) {
      $sidebar.removeClass("app-active");
      $mobileToggle.removeClass("app-active");
      $body.removeClass("mobile-menu-open");
    }
  });

  $menuListItems.on("click", function () {
    $menuListItems.removeClass("app-active");
    $(this).addClass("app-active");

    if (window.innerWidth <= 991.98) {
      $sidebar.removeClass("app-active");
      $mobileToggle.removeClass("app-active");
      $body.removeClass("mobile-menu-open");
    }
  });

  $('[data-bs-toggle="tooltip"]').tooltip();

  // Alert auto-dismiss
  function setupAlertDismissal() {
    setTimeout(function () {
      $('.custom_tfh_alert').fadeOut(500, function () {
        $(this).remove();
      });
    }, 5000);
  }

  setupAlertDismissal();

  // Zoom link
  $('.zoom-link').off('click.zoom').on('click.zoom', function (e) {
    e.preventDefault();
    const imgUrl = $(this).data('img-url');
    $('#modalImage').attr('src', imgUrl);

    const myModal = new bootstrap.Modal(document.getElementById('imageModal'));
    myModal.show();
  });

  // Currency formatting
  const $inputs = $('[data-behavior="currency-format"]');

  function formatWithCommas(value) {
    if (!value) return "";

    let parts = value.split(".");
    let integerPart = parts[0];
    let decimalPart = parts.length > 1 ? "." + parts[1] : "";

    integerPart = integerPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    return integerPart + decimalPart;
  }

  $inputs.off("input.currency").on("input.currency", function () {
    let $this = $(this);
    let val = $this.val().replace(/[^0-9.]/g, "");

    let parts = val.split(".");
    if (parts.length > 2) {
      val = parts[0] + "." + parts[1];
    }
    $this.val(formatWithCommas(val));
  });

  $inputs.off("blur.currency").on("blur.currency", function () {
    $(this).val(formatWithCommas($(this).val()));
  });

  window.showFlashMessage = function (message, type = "danger") {
    $('.custom_tfh_alert').remove();

    let messages = message.split(/<br\s*\/?>/i).map(m => m.trim()).filter(Boolean);
    let messageHtml;

    if (messages.length > 1) {
      messageHtml = `<div class="mb-0">${messages.map(m => `<div>${m}</div>`).join("")}</div>`;
    } else {
      messageHtml = `<span>${messages[0]}</span>`;
    }

    const flashHtml = `
            <div class="custom_tfh_alert alert alert-dismissible show d-flex align-items-start"
                role="alert"
                style="position: fixed; top: 20px; right: 20px; z-index: 9999; max-width: 400px; word-wrap: break-word; overflow-wrap: break-word;">
                <i class="fa-solid fa-circle-exclamation me-2 mt-1 alert_text_${type}"></i>
                <div style="min-width: 0; word-wrap: break-word; overflow-wrap: break-word;">
                    ${messageHtml}
                </div>
            </div>
        `;
    $('body').prepend(flashHtml);

    setTimeout(function () {
      $('.custom_tfh_alert').fadeOut(500, function () {
        $(this).remove();
      });
    }, 5000);
  };

  $('div.dataTables_filter input').attr('placeholder', 'Search...');

  $('.dataTables_wrapper [class*="col-sm-"], .dataTables_wrapper [class*="col-md-"], .dataTables_wrapper [class*="col-12"]').each(function () {
    let current = $(this).attr('class');

    // Replace col-sm-* and col-md-* with col-*
    current = current
      .replace(/\bcol-sm-/g, 'col-')
      .replace(/\bcol-md-/g, 'col-');

    // If both col-6 and col-12 exist, remove col-12
    if (/\bcol-6\b/.test(current) && /\bcol-12\b/.test(current)) {
      current = current.replace(/\bcol-12\b/g, '');
    }

    // Clean extra spaces
    current = current.replace(/\s+/g, ' ').trim();

    $(this).attr('class', current);
  });

  // When a tab becomes visible, recalc the datatable layout
  $(document).off('shown.bs.tab.dt').on('shown.bs.tab.dt', '[data-bs-toggle="tab"]', function (e) {
    $.fn.dataTable
      .tables({ visible: true, api: true })
      .columns.adjust()
      .responsive.recalc();
  });
}

// Bind to Turbo Load
document.addEventListener("turbo:load", () => {
  window.isNavigatingConfirmed = false;
  // Clear any cached company selector state on page load to ensure fresh data
  const input = document.getElementById('company_search_input');
  if (input) {
    input.dataset.loadedDefault = "false";
  }

  initApplication();
  loadPageSpecificModules();

  // Force full reload for companies page to prevent cache issues
  if (window.location.pathname.includes("/companies")) {
    const companyForm = document.getElementById('company-form');
    if (companyForm) {
      // Remove any cached form data
      companyForm.reset();
      // Re-enable submit button
      const submitBtn = document.getElementById('update-company-btn');
      if (submitBtn) {
        submitBtn.disabled = false;
      }
    }
  }
});
// Specifically handle the 422 error re-render
document.addEventListener("turbo:render", () => {
  window.isNavigatingConfirmed = false;
  initApplication();
  loadPageSpecificModules();
});
// Also bind to DOMContentLoaded for initial non-Turbo load if any
document.addEventListener("DOMContentLoaded", () => {
  window.isNavigatingConfirmed = false;
  initApplication();
  loadPageSpecificModules();
});

// Clear cached data on logout
document.addEventListener("turbo:before-fetch-request", (event) => {
  const url = event.detail.url?.toString();
  if (url && url.includes("/users/sign_out")) {
    // Clear company selector cached state
    const input = document.getElementById('company_search_input');
    if (input) {
      input.dataset.loadedDefault = "false";
    }
    // Clear dropdown
    const dropdown = document.getElementById('company_search_dropdown');
    if (dropdown) {
      dropdown.innerHTML = '';
    }
    // Clear hidden input
    const hiddenInput = document.getElementById('recipient_company_id');
    if (hiddenInput) {
      hiddenInput.value = '';
    }
    // Clear sessionStorage data that might persist
    sessionStorage.clear();
  }
});

// Reload visible server-side DataTables when a page is restored from bfcache
window.addEventListener('pageshow', function (event) {
  if (event.persisted) {
    const companyForm = document.getElementById('company-form');
    if (companyForm) {
      companyForm.reset();
      const imagePreview = companyForm.querySelector('#image-preview');
      if (imagePreview && imagePreview.dataset.defaultSrc) {
        imagePreview.src = imagePreview.dataset.defaultSrc;
      }
      const fileInput = companyForm.querySelector('#profile_image_input');
      if (fileInput) {
        fileInput.value = '';
      }
    }
  }
  if (!event.persisted) return;
  if (typeof $ === 'undefined' || !$.fn.DataTable) return;

  $.fn.dataTable.tables({ api: true }).every(function () {
    if (this.ajax) {
      this.ajax.reload(null, false);
    }
  });
});

// Global Teardown for DataTables and Modals to fix Turbo Caching issues
document.addEventListener("turbo:before-cache", function () {
  window.isNavigatingConfirmed = false;
  const confirmModal = document.getElementById('turboConfirmModal');
  if (confirmModal) {
    confirmModal.remove();
  }
  document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
  document.body.classList.remove('modal-open');
  document.body.style.removeProperty('overflow');
  document.body.style.removeProperty('padding-right');

  if (typeof $ !== 'undefined' && $.fn.DataTable) {
    $('.dataTable, .submissionsTable, #taxSubmissionsTableActive, #taxSubmissionsTableArchived').each(function () {
      if ($.fn.DataTable.isDataTable(this)) {
        const dt = $(this).DataTable();
        if (dt) dt.destroy();
      }
    });
  }

  const companyForm = document.getElementById('company-form');
  if (companyForm) {
    companyForm.reset();
    const imagePreview = companyForm.querySelector('#image-preview');
    if (imagePreview && imagePreview.dataset.defaultSrc) {
      imagePreview.src = imagePreview.dataset.defaultSrc;
    }
    const fileInput = companyForm.querySelector('#profile_image_input');
    if (fileInput) {
      fileInput.value = '';
    }
  }
});

// Refresh form authenticity token when page is restored from cache
document.addEventListener("turbo:load", function () {
  const companyForm = document.getElementById('company-form');
  if (companyForm) {
    // Get a fresh CSRF token from meta tag
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
    if (csrfToken) {
      const tokenInput = companyForm.querySelector('input[name="authenticity_token"]');
      if (tokenInput) {
        tokenInput.value = csrfToken;
      }
    }
  }
});

// Prefetch page modules on link hover for faster navigation
let prefetchTimeout;
document.addEventListener('mouseover', function (e) {
  const link = e.target.closest('a[href^="/"]');
  if (!link || link.href.includes('#') || link.dataset.prefetched) return;

  clearTimeout(prefetchTimeout);
  prefetchTimeout = setTimeout(() => {
    // Don't prefetch external links or data: urls
    if (link.origin !== window.location.origin) return;

    // Mark as prefetched to avoid duplicate work
    link.dataset.prefetched = 'true';

    // Prefetch the page module based on path
    const path = new URL(link.href).pathname;
    if (path.includes('/invoices/new') || path.includes('/invoices/') && path.includes('/edit')) {
      // Prefetch invoice form module
      import(/* webpackPrefetch: true */ './invoice');
    }
  }, 100);
}, { passive: true });

// ==========================================================================
// INTEGRATED SIDEBAR HEADER: COMMAND PALETTE & THEME TOGGLE
// ==========================================================================

// 1. Command Palette Keyboard Shortcut (Ctrl+K / Cmd+K)
document.addEventListener('keydown', function (e) {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault();
    const modalEl = document.getElementById('commandPaletteModal');
    if (modalEl && typeof bootstrap !== 'undefined') {
      const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
      modal.toggle();
    }
  }
});

document.addEventListener('DOMContentLoaded', function () {
  setupCommandPalette();
  setupHeaderThemeToggle();
});

document.addEventListener('turbo:load', function () {
  setupCommandPalette();
  setupHeaderThemeToggle();
});

function setupHeaderThemeToggle() {
  const headerThemeBtn = document.getElementById('header_theme_toggle');
  if (!headerThemeBtn) return;

  headerThemeBtn.addEventListener('click', function (e) {
    e.preventDefault();
    e.stopPropagation();
    const mainToggle = document.getElementById('theme_toggle_btn');
    if (mainToggle) {
      mainToggle.click();
    } else {
      const htmlEl = document.documentElement;
      const currentTheme = htmlEl.getAttribute('data-theme') || 'light';
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
      htmlEl.setAttribute('data-theme', newTheme);
      htmlEl.setAttribute('data-bs-theme', newTheme);
    }

    const themeStatus = document.getElementById('header_theme_status');
    if (themeStatus) {
      const activeTheme = document.documentElement.getAttribute('data-theme') || 'light';
      themeStatus.textContent = activeTheme.charAt(0).toUpperCase() + activeTheme.slice(1) + ' Mode';
    }
  });
}

function setupCommandPalette() {
  const modalEl = document.getElementById('commandPaletteModal');
  const inputEl = document.getElementById('command_palette_input');
  if (!modalEl || !inputEl) return;

  modalEl.addEventListener('shown.bs.modal', function () {
    inputEl.value = '';
    inputEl.focus();
    filterCommandItems('');
  });

  inputEl.removeEventListener('input', handleCommandInput);
  inputEl.addEventListener('input', handleCommandInput);
}

function handleCommandInput(e) {
  filterCommandItems(e.target.value);
}

function filterCommandItems(query) {
  const items = document.querySelectorAll('#command_palette_results .command-item');
  const q = query.toLowerCase().trim();

  items.forEach(item => {
    const text = item.textContent.toLowerCase();
    if (!q || text.includes(q)) {
      item.classList.remove('d-none');
    } else {
      item.classList.add('d-none');
    }
  });
}

// Smart Back Button Navigation Handler
document.addEventListener('click', function (e) {
  const backBtn = e.target.closest('a.btn-back, a[data-behavior="back-button"]');
  if (!backBtn) return;

  // Ignore if user used modifier keys (Cmd/Ctrl+click to open in new tab)
  if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  if (backBtn.target === '_blank') return;

  // If form has unsaved changes and confirmation hasn't occurred yet, let dirty form handler manage it
  if (window.isInvoiceFormDirty && !window.isNavigatingConfirmed) return;

  const referrer = document.referrer;
  const isInternalReferrer = referrer && referrer.includes(window.location.host);
  const isAuthPage = referrer && (
    referrer.includes('/users/sign_in') ||
    referrer.includes('/users/sign_up') ||
    referrer.includes('/users/password')
  );

  // If we came from an internal page within the app (excluding auth/sign-in flows)
  if (window.history.length > 1 && isInternalReferrer && !isAuthPage) {
    e.preventDefault();
    window.history.back();
  }
});





