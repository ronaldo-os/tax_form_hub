import "jquery";
import "bootstrap";
import "@hotwired/turbo-rails";

$(document).on("turbo:load", function () {
  $(".alert").delay(3000).fadeOut(500);
});
