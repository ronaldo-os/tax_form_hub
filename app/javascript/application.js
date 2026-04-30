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

  if (path.includes('/recurring_invoices')) {
    import(/* webpackChunkName: "recurring_line_items" */ './recurring_line_items');
  }

  if (path.includes('/edit_profile') || path.includes('/users/edit')) {
    import(/* webpackChunkName: "edit_profile" */ './edit_profile');
  }
}

// Always load network search (small utility)
import './network_search';


import Rails from "@rails/ujs";
import "@hotwired/turbo-rails";
Rails.start();



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
    localStorage.setItem('theme', newTheme);
    updateThemeUI(newTheme);
    
    // Dispatch custom event to notify components of theme change
    const event = new CustomEvent('theme:changed', { detail: { theme: newTheme } });
    document.dispatchEvent(event);
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
    
    // Initial UI update
    updateThemeUI(savedTheme);

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



