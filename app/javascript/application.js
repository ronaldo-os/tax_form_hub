import "./client_submissions";
import "./admin_client_submissions";
import "./edit_profile";
import "./index_invoice.js";
import "./invoice";
import "./locations";
import "./companies.js";
import "./recurring_line_items.js";


import Rails from "@rails/ujs";
Rails.start();

$(document).ready(function () {

    $('.global-wrapper aside')
    .on('mouseenter', function() {
    $('body').css('overflow-x', 'hidden');
    })
    .on('mouseleave', function() {
    $('body').css('overflow-x', '');
    });

    $(function () {
      $('[data-bs-toggle="tooltip"]').tooltip();
    });

    setTimeout(function () {
        $('.custom_tfh_alert').fadeOut(500, function () {
            $(this).remove();
        });
    }, 5000);

    $('.zoom-link').on('click', function (e) {
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

    $inputs.on("input", function () {
        let $this = $(this);
        let val = $this.val().replace(/[^0-9.]/g, "");

        let parts = val.split(".");
        if (parts.length > 2) {
          val = parts[0] + "." + parts[1];
        }
        $this.val(formatWithCommas(val));
    });

    $inputs.on("blur", function () {
        $(this).val(formatWithCommas($(this).val()));
    });

    function showFlashMessage(message, type = "danger", title = null) {
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
                    ${title ? `<h5 class="mb-1">${title}</h5>` : ""}
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
    }

    window.showFlashMessage = showFlashMessage;
});

