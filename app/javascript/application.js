import "./network_search";
// Page specific JS are now loaded in their respective views
// import "./client_submissions";
// import "./admin_client_submissions";
// import "./edit_profile";
// import "./index_invoice.js";
// import "./network_search";
// import "./invoice";
// import "./view_invoice.js";
// import "./locations";
// import "./companies.js";
// import "./recurring_line_items.js";


import Rails from "@rails/ujs";
import "@hotwired/turbo-rails";
Rails.start();


function initApplication() {

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
    const $menuListItems = $(".app-menu-list li, .app-bottom li");

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
    setTimeout(function () {
        $('.custom_tfh_alert').fadeOut(500, function () {
            $(this).remove();
        });
    }, 5000);

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
            messageHtml = `<ol class="mb-0 ps-3">${messages.map(m => `<li>${m}</li>`).join("")}</ol>`;
        } else {
            messageHtml = `<span>${messages[0]}</span>`;
        }

        const flashHtml = `
            <div class="custom_tfh_alert alert alert-dismissible show d-flex align-items-start"
                role="alert"
                style="position: fixed; top: 20px; right: 20px; z-index: 9999; max-width: 400px;">
                <i class="fa-solid fa-circle-exclamation me-2 mt-1 alert_text_${type}"></i>
                <div>
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
document.addEventListener("turbo:load", initApplication);
// Also bind to DOMContentLoaded for initial non-Turbo load if any
document.addEventListener("DOMContentLoaded", initApplication);

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



