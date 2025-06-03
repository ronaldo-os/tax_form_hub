import "./devise_password_toggle";
import "./client_submissions";
import "./admin_client_submissions";
import Rails from "@rails/ujs";
Rails.start();

$(document).ready(function () {
    setTimeout(function () {
        $('.custom_tfh_alert').fadeOut(500, function () {
          $(this).remove();
        });
    }, 3000); 
});
