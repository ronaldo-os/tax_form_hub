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

  if (path.includes('/tax_submissions') || path === '/') {
    import(/* webpackChunkName: "client_submissions" */ './client_submissions');
  }

  if (path.includes('/admin')) {
    import(/* webpackChunkName: "admin_client_submissions" */ './admin_client_submissions');
  }

  if (path.includes('/locations')) {
    import(/* webpackChunkName: "locations" */ './locations');
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

// Register Service Worker for PWA functionality (skip in development)
const isDevelopment = window.location.hostname === 'localhost' ||
                      window.location.hostname === '127.0.0.1' ||
                      window.location.port === '3000' || 
                      window.location.port === '9007';

if ('serviceWorker' in navigator && !isDevelopment) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then((registration) => {
        console.log('[PWA] Service Worker registered:', registration.scope);

        // Check for updates periodically
        setInterval(() => {
          registration.update();
        }, 60 * 60 * 1000); // Check every hour
      })
      .catch((error) => {
        console.log('[PWA] Service Worker registration failed:', error);
      });

    // Listen for service worker updates
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[PWA] New service worker activated, reloading...');
      window.location.reload();
    });
  });
} else if (isDevelopment) {
  console.log('[PWA] Service Worker disabled in development mode');
}

import Rails from "@rails/ujs";
import "@hotwired/turbo-rails";
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

// Register all controllers
stimulusApplication.register('email-validation', EmailValidationController);
stimulusApplication.register('lazy-loader', LazyLoaderController);
stimulusApplication.register('password-toggle', PasswordToggleController);
stimulusApplication.register('sidebar', SidebarController);

function updateThemeUI(theme) {
    const btn = document.getElementById('theme_toggle_btn');
    if (!btn) {
        console.warn('Theme button not found');
        return;
    }
    
    // Find the icon and text - they're inside the <a> tag
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
}

function handleThemeToggle(e) {
    e.preventDefault();
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
    const newTheme = currentTheme === 'light' ? 'dark' : 'light';

    console.log('Theme toggle clicked. Current:', currentTheme, 'New:', newTheme);
    
    document.documentElement.setAttribute('data-theme', newTheme);
    document.documentElement.setAttribute('data-bs-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    updateThemeUI(newTheme);
    
    // Update dynamic elements that don't automatically respond to theme changes
    updateDynamicElementsForTheme(newTheme);
    
    // Dispatch custom event to notify components of theme change
    const event = new CustomEvent('theme:changed', { detail: { theme: newTheme } });
    document.dispatchEvent(event);
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
        $('.dataTable').each(function() {
            const dt = $(this).DataTable();
            // Redraw without resetting paging to apply new theme styles
            dt.draw(false);
        });
        
        // Update DataTable pagination and info elements
        $('.dataTables_wrapper .dataTables_info, .dataTables_wrapper .dataTables_paginate').each(function() {
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
    const themeBtn = e.target.closest('#theme_toggle_btn');
    if (themeBtn) {
        handleThemeToggle(e);
    }
}

function initApplication() {
    // Theme Toggle Logic - Ensure theme is synced from localStorage (especially after Turbo navigation)
    const savedTheme = localStorage.getItem('theme') || 'light';
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
    $(document).off('click.pw-toggle').on('click.pw-toggle', '.toggle-password-icon', function (event) {
        event.preventDefault();

        const $icon = $(this);
        const $inputGroup = $icon.closest('.input-group');
        const $input = $inputGroup.find('input');

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
    const $sidebar = $(".app-sidebar");
    // Exclude the theme toggle button from the menu list items
    const $menuListItems = $(".app-menu-list li, .app-bottom li").not("#theme_toggle_btn");

    // Remove existing handlers to prevent duplicate binding
    $menuToggle.off("click");
    $mobileToggle.off("click");
    $menuListItems.off("click");

    // === Desktop toggle ===
    $menuToggle.on("click", function () {
        $menuToggle.toggleClass("app-active");
        $sidebar.toggleClass("app-active");
    });

    // === Mobile toggle ===
    $mobileToggle.on("click", function () {
        $mobileToggle.toggleClass("app-active");
        $sidebar.toggleClass("app-active");
    });

    $menuListItems.on("click", function () {
        $menuListItems.removeClass("app-active");
        $(this).addClass("app-active");

        if (window.innerWidth <= 768) {
            $sidebar.removeClass("app-active");
            $mobileToggle.removeClass("app-active");
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
    $(document).off('shown.bs.tab.dt').on('shown.bs.tab.dt', 'a[data-bs-toggle="tab"]', function (e) {
        $.fn.dataTable
            .tables({ visible: true, api: true })
            .columns.adjust()
            .responsive.recalc();
    });
}

// Bind to Turbo Load
document.addEventListener("turbo:load", () => {
  initApplication();
  loadPageSpecificModules();
});
// Specifically handle the 422 error re-render
document.addEventListener("turbo:render", initApplication);
// Also bind to DOMContentLoaded for initial non-Turbo load if any
document.addEventListener("DOMContentLoaded", () => {
  initApplication();
  loadPageSpecificModules();
});

// Reload visible server-side DataTables when a page is restored from bfcache
window.addEventListener('pageshow', function (event) {
  if (!event.persisted) return;
  if (typeof $ === 'undefined' || !$.fn.dataTable) return;

  $.fn.dataTable.tables({ api: true }).every(function () {
    if (this.ajax) {
      this.ajax.reload(null, false);
    }
  });
});

// Global Teardown for DataTables to fix Turbo Caching issues
document.addEventListener("turbo:before-cache", function () {
    if ($.fn.DataTable) {
        $('.dataTable').each(function () {
            // Destroy the DataTable, removing the structure, so the cache saves a clean table
            const dt = $(this).DataTable();
            if (dt) dt.destroy();
        });
    }
});

// Prefetch page modules on link hover for faster navigation
let prefetchTimeout;
document.addEventListener('mouseover', function(e) {
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



