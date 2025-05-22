$(document).ready(function() {

  // Change Password Page (toggle #password and #confirmPassword)
  if ($('#togglePasswordIcon').length && $('#toggleConfirmPasswordIcon').length) {
    $('#togglePasswordIcon').on('click', function() {
      const passwordInput = $('#password');
      const type = passwordInput.attr('type') === 'password' ? 'text' : 'password';
      passwordInput.attr('type', type);
      $(this).toggleClass('fa-eye fa-eye-slash');
    });

    $('#toggleConfirmPasswordIcon').on('click', function() {
      const confirmInput = $('#confirmPassword');
      const type = confirmInput.attr('type') === 'password' ? 'text' : 'password';
      confirmInput.attr('type', type);
      $(this).toggleClass('fa-eye fa-eye-slash');
    });
  }

  // Signup Page (toggle #password and #password_confirmation)
  else if ($('#togglePasswordIcon').length && $('#toggleConfirmIcon').length) {
    $('#togglePasswordIcon').on('click', function() {
      const input = $('#password');
      const type = input.attr('type') === 'password' ? 'text' : 'password';
      input.attr('type', type);
      $(this).toggleClass('fa-eye fa-eye-slash');
    });

    $('#toggleConfirmIcon').on('click', function() {
      const input = $('#password_confirmation');
      const type = input.attr('type') === 'password' ? 'text' : 'password';
      input.attr('type', type);
      $(this).toggleClass('fa-eye fa-eye-slash');
    });
  }

  // Login Page (toggle only #password)
  else if ($('#togglePasswordIcon').length) {
    $('#togglePasswordIcon').on('click', function() {
      const passwordInput = $('#password');
      const type = passwordInput.attr('type') === 'password' ? 'text' : 'password';
      passwordInput.attr('type', type);
      $(this).toggleClass('fa-eye fa-eye-slash');
    });
  }

});
