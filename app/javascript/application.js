import "./devise_password_toggle";
import "./client_submissions";
import "./admin_client_submissions";
import "./edit_profile";
import "./invoice";
import "./locations";
import "./companies.js";
import "./recurring_line_items.js";


import Rails from "@rails/ujs";
Rails.start();

$(document).ready(function () {
    setTimeout(function () {
        $('.custom_tfh_alert').fadeOut(500, function () {
          $(this).remove();
        });
    }, 3000); 

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
});
