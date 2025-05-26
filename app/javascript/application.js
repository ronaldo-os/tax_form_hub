import "@hotwired/turbo-rails"
import "bootstrap"
import $ from "jquery"
window.$ = $
window.jQuery = $


$(document).on('turbo:load', function () {
  if ($('body').hasClass('devise')) {
    import('./devise_password_toggle')
      .then(module => {
        if (typeof module.default === 'function') {
          module.default();
        }
      })
      .catch(error => console.error("Failed to load devise toggle:", error));
  }
});
