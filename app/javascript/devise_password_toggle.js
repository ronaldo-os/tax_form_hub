if (document.body.dataset.devise === "true") {
    $(document).ready(function () {

      if ($('#togglePasswordIcon').length && $('#toggleConfirmPasswordIcon').length) {
        $('#togglePasswordIcon').on('click', function () {
          const passwordInput = $('#password');
          const type = passwordInput.attr('type') === 'password' ? 'text' : 'password';
          passwordInput.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });

        $('#toggleConfirmPasswordIcon').on('click', function () {
          const confirmInput = $('#confirmPassword');
          const type = confirmInput.attr('type') === 'password' ? 'text' : 'password';
          confirmInput.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });
      }

      else if ($('#togglePasswordIcon').length && $('#toggleConfirmIcon').length) {
        $('#togglePasswordIcon').on('click', function () {
          const input = $('#password');
          const type = input.attr('type') === 'password' ? 'text' : 'password';
          input.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });

        $('#toggleConfirmIcon').on('click', function () {
          const input = $('#password_confirmation');
          const type = input.attr('type') === 'password' ? 'text' : 'password';
          input.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });
      }

      else if ($('#togglePasswordIcon').length) {
        $('#togglePasswordIcon').on('click', function () {
          const passwordInput = $('#password');
          const type = passwordInput.attr('type') === 'password' ? 'text' : 'password';
          passwordInput.attr('type', type);
          $(this).toggleClass('fa-eye fa-eye-slash');
        });
      }


      $('.needs-validation').on('submit', function(event) {
        if (this.checkValidity() === false) {
          event.preventDefault();
          event.stopPropagation();
        }
        $(this).addClass('was-validated');
      });

  });
}
