if (document.body.dataset.devise === "true") {
  $(document).ready(function () {
    const toggleIcon = (iconId, inputId) => {
      const $icon = $(`#${iconId}`);
      const $input = $(`#${inputId}`);
      if ($icon.length && $input.length) {
        $icon.on('click', function () {
          const type = $input.attr('type') === 'password' ? 'text' : 'password';
          $input.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });
      }
    };

    toggleIcon('togglePasswordIcon', 'password');
    toggleIcon('toggleConfirmPasswordIcon', 'confirmPassword');
    toggleIcon('toggleConfirmIcon', 'password_confirmation');

    $('.needs-validation').on('submit', function (event) {
      if (!this.checkValidity()) {
        event.preventDefault();
        event.stopPropagation();
      }
      $(this).addClass('was-validated');
    });
  });
}
