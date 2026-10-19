(function() {
    let initialProfileState = {
        email: '',
        currency: '',
        avatarSrc: '',
        hasAvatar: false
    };
    window._profileAvatarDirty = false;
    window.isProfileSubmitting = false;

    // We use a shared function to handle the preview logic
    function handleImagePreview(file, $previewElement, $submitBtn) {
        const $errorMsg = $('#avatar_error_msg');
        if (!file) {
            window._profileAvatarDirty = false;
            return;
        }

        if (!file.type.startsWith('image/')) {
            if ($errorMsg.length) {
                $errorMsg.text("Please select a valid image file.").show();
            }
            if ($submitBtn) $submitBtn.prop('disabled', true);
            $previewElement.css('border', '2px solid red');
            const fileInput = document.getElementById('profile_image_input');
            if (fileInput) fileInput.value = '';
            window._profileAvatarDirty = false;
            return;
        }

        if ($errorMsg.length) {
            $errorMsg.text('').hide();
        }
        $previewElement.css('border', '');

        const reader = new FileReader();
        reader.onload = function (e) {
            $previewElement.attr('src', e.target.result).css('display', 'block').show();
            $previewElement.attr('style', '');
            $('#initials-preview').attr('style', 'display: none !important');
            if ($submitBtn) $submitBtn.prop('disabled', false);
            $('.text-danger.small').not('#avatar_error_msg').fadeOut(500);
            window._profileAvatarDirty = true;
        };
        reader.readAsDataURL(file);
    }

    function initProfileBaseline() {
        const form = document.getElementById('edit_profile_form') || document.querySelector('.profile-edit-card form');
        if (!form) {
            window.currentProfileUrl = null;
            return;
        }

        window.currentProfileUrl = window.location.href;
        window.isProfileSubmitting = false;
        window._profileAvatarDirty = false;

        const emailInput = document.getElementById('user_email') || form.querySelector('input[type="email"]');
        const currencySelect = document.getElementById('user_currency_select') || form.querySelector('select[name="user[currency]"]');
        const imagePreview = document.getElementById('image-preview');
        const fileInput = document.getElementById('profile_image_input');

        if (fileInput) {
            fileInput.value = '';
        }

        const initialEmail = (
            (emailInput && emailInput.dataset && emailInput.dataset.initialValue)
                ? emailInput.dataset.initialValue
                : (emailInput ? (emailInput.defaultValue || emailInput.getAttribute('value') || emailInput.value || '') : '')
        ).trim();

        if (emailInput) {
            emailInput.dataset.initialValue = initialEmail;
        }

        const defaultOpt = currencySelect ? currencySelect.querySelector('option[selected]') : null;
        const initialCurrency = (
            (currencySelect && currencySelect.dataset && currencySelect.dataset.initialValue)
                ? currencySelect.dataset.initialValue
                : (defaultOpt ? defaultOpt.value : (currencySelect ? currencySelect.value : ''))
        );

        if (currencySelect) {
            currencySelect.dataset.initialValue = initialCurrency;
        }

        let hasAvatar = false;
        let avatarSrc = '';
        if (imagePreview) {
            avatarSrc = imagePreview.getAttribute('src') || '';
            const isHidden = imagePreview.style.display === 'none' ||
                imagePreview.getAttribute('style')?.includes('display: none') ||
                !avatarSrc;
            hasAvatar = !isHidden;
        }

        initialProfileState = {
            email: initialEmail,
            currency: initialCurrency,
            avatarSrc: avatarSrc,
            hasAvatar: hasAvatar
        };

        // Reset user modified flags on password inputs
        const passwordInput = document.getElementById('password');
        const passwordConfirmInput = document.getElementById('password_confirmation');
        const currentPasswordInput = document.getElementById('current_password');

        if (passwordInput && !passwordInput.dataset.userModified) passwordInput.value = '';
        if (passwordConfirmInput && !passwordConfirmInput.dataset.userModified) passwordConfirmInput.value = '';
        if (currentPasswordInput && !currentPasswordInput.dataset.userModified) currentPasswordInput.value = '';

        // Form submission handler to prevent warning when actually saving
        $(form).off('submit.profile_save').on('submit.profile_save', function() {
            window.isProfileSubmitting = true;
        });
    }

    window.isProfileDirty = function() {
        const form = document.getElementById('edit_profile_form') || document.querySelector('.profile-edit-card form');
        if (!form) return false;
        if (window.isProfileSubmitting) return false;

        // 1. Avatar check
        const fileInput = document.getElementById('profile_image_input');
        if (fileInput && fileInput.files && fileInput.files.length > 0) {
            return true;
        }
        if (window._profileAvatarDirty) {
            return true;
        }

        // 2. Email Address check
        const emailInput = document.getElementById('user_email') || form.querySelector('input[type="email"]');
        if (emailInput) {
            const currentEmail = (emailInput.value || '').trim();
            const initialEmail = (
                (emailInput.dataset && emailInput.dataset.initialValue !== undefined && emailInput.dataset.initialValue !== null)
                    ? emailInput.dataset.initialValue
                    : (emailInput.defaultValue !== undefined && emailInput.defaultValue !== null && emailInput.defaultValue !== ''
                        ? emailInput.defaultValue
                        : (emailInput.getAttribute('value') || initialProfileState.email || currentEmail))
            ).trim();

            if (currentEmail !== initialEmail) {
                return true;
            }
        }

        // 3. Preferred Dashboard Currency check
        const currencySelect = document.getElementById('user_currency_select') || form.querySelector('select[name="user[currency]"]');
        if (currencySelect) {
            const currentCurrency = currencySelect.value;
            const defaultOpt = currencySelect.querySelector('option[selected]');
            const initialCurrency = (
                (currencySelect.dataset && currencySelect.dataset.initialValue !== undefined && currencySelect.dataset.initialValue !== null)
                    ? currencySelect.dataset.initialValue
                    : (defaultOpt ? defaultOpt.value : (initialProfileState.currency || currentCurrency))
            );

            if (currentCurrency !== initialCurrency) {
                return true;
            }
        }

        // 4. Password Settings check (New Password, Confirm New Password, Current Password)
        // Values are not persisted or stored; only checked for presence on DOM elements
        const passwordInput = document.getElementById('password');
        const passwordConfirmInput = document.getElementById('password_confirmation');
        const currentPasswordInput = document.getElementById('current_password');

        if (passwordInput && passwordInput.value.length > 0) return true;
        if (passwordConfirmInput && passwordConfirmInput.value.length > 0) return true;
        if (currentPasswordInput && currentPasswordInput.value.length > 0) return true;

        return false;
    };

    window.discardProfileChanges = function() {
        const form = document.getElementById('edit_profile_form') || document.querySelector('.profile-edit-card form');
        if (!form) return;

        // 1. Reset standard form fields (Email, Currency, Passwords)
        form.reset();

        // 2. Reset email & currency inputs to baseline
        const emailInput = document.getElementById('user_email') || form.querySelector('input[type="email"]');
        if (emailInput) {
            const baseline = (emailInput.dataset && emailInput.dataset.initialValue) || initialProfileState.email;
            if (baseline) emailInput.value = baseline;
        }

        const currencySelect = document.getElementById('user_currency_select') || form.querySelector('select[name="user[currency]"]');
        if (currencySelect) {
            const baseline = (currencySelect.dataset && currencySelect.dataset.initialValue) || initialProfileState.currency;
            if (baseline) currencySelect.value = baseline;
        }

        // 3. Reset password inputs
        const passwordInput = document.getElementById('password');
        const passwordConfirmInput = document.getElementById('password_confirmation');
        const currentPasswordInput = document.getElementById('current_password');
        if (passwordInput) {
            passwordInput.value = '';
            delete passwordInput.dataset.userModified;
        }
        if (passwordConfirmInput) {
            passwordConfirmInput.value = '';
            delete passwordConfirmInput.dataset.userModified;
        }
        if (currentPasswordInput) {
            currentPasswordInput.value = '';
            delete currentPasswordInput.dataset.userModified;
        }

        // 4. Reset file input
        const fileInput = document.getElementById('profile_image_input');
        if (fileInput) {
            fileInput.value = '';
        }

        // 5. Reset image preview & initials display
        const $imagePreview = $('#image-preview');
        const $initialsPreview = $('#initials-preview');
        if ($imagePreview.length) {
            if (initialProfileState.hasAvatar) {
                $imagePreview.attr('src', initialProfileState.avatarSrc).css('display', 'block').show();
                $imagePreview.attr('style', '');
                $initialsPreview.attr('style', 'display: none !important');
            } else {
                $imagePreview.attr('src', '').attr('style', 'display: none !important;').hide();
                $initialsPreview.removeAttr('style').css('display', 'flex').show();
            }
            $imagePreview.css('border', '');
        }

        const $errorMsg = $('#avatar_error_msg');
        if ($errorMsg.length) {
            $errorMsg.text('').hide();
        }

        // 6. Reset flags
        window._profileAvatarDirty = false;
        window.isProfileSubmitting = false;

        // 7. Invalidate Turbo snapshot cache so discarded changes cannot be restored
        if (typeof Turbo !== 'undefined' && Turbo.cache && typeof Turbo.cache.clear === 'function') {
            Turbo.cache.clear();
        }
    };

    // Attach delegated listeners to $(document) so they persist across Turbo renders
    function initDelegatedListeners() {
        const doc = $(document);

        // Track user interaction with password inputs
        doc.off('input.profile_pw', '#password, #password_confirmation, #current_password')
           .on('input.profile_pw', '#password, #password_confirmation, #current_password', function () {
               if (this.value.length > 0) {
                   this.dataset.userModified = 'true';
               } else {
                   delete this.dataset.userModified;
               }
           });

        // Click wrapper to trigger file input (if not clicking the input/label themselves)
        doc.off('click.profile', '#image-preview-wrapper').on('click.profile', '#image-preview-wrapper', function (e) {
            const $fileInput = $('#profile_image_input');
            if ($(e.target).is($fileInput) || $(e.target).closest('label').length > 0) {
                return;
            }
            $fileInput.click();
        });

        // Prevent infinite loop if file input itself is clicked directly
        doc.off('click.profile', '#profile_image_input').on('click.profile', '#profile_image_input', function (e) {
            e.stopPropagation();
        });

        // Handle image selection
        doc.off('change.profile', '#profile_image_input').on('change.profile', '#profile_image_input', function (e) {
            const file = e.target.files ? e.target.files[0] : null;
            const $imagePreview = $('#image-preview');
            const $submitBtn = $('#update-profile-btn');
            handleImagePreview(file, $imagePreview, $submitBtn);
        });

        // Clear errors when focusing/typing in any input
        doc.off('focus.profile input.profile', 'input').on('focus.profile input.profile', 'input', function() {
            $(this).removeClass('is-invalid');
            $(this).closest('.mb-4').find('.text-danger.small').fadeOut(500);
            $(this).closest('.input-group').find('.input-group-text').removeClass('border-danger');
        });
    }

    // Initialize once
    initDelegatedListeners();
    
    // For things that still need to run on every load
    function runOnEveryLoad() {
        initProfileBaseline();
        if ($('#image-preview').length) {
            // Auto-hide alert messages (flashes) and errors after 5 seconds
            setTimeout(function() {
                $('.alert, .text-danger.small').fadeOut(1000);
            }, 5000);
        }
    }

    window.initEditProfile = runOnEveryLoad;

    // Listen on both jQuery and native DOM events to guarantee baseline initialization
    $(document).on('turbo:load', runOnEveryLoad);
    $(document).on('turbo:render', runOnEveryLoad);
    $(document).on('DOMContentLoaded', runOnEveryLoad);

    document.addEventListener('turbo:load', runOnEveryLoad);
    document.addEventListener('turbo:render', runOnEveryLoad);
    document.addEventListener('DOMContentLoaded', runOnEveryLoad);
})();
