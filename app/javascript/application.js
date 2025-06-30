import "./devise_password_toggle";
import "./client_submissions";
import "./admin_client_submissions";
import "./edit_profile";
import "./invoice";
import "./locations";
import "./companies.js";


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
});
