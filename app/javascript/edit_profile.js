(function() {
    // We use a shared function to handle the preview logic
    function handleImagePreview(file, $previewElement, $submitBtn) {
        if (!file) return;

        if (!file.type.startsWith('image/')) {
            alert("Please select a valid image file.");
            if ($submitBtn) $submitBtn.prop('disabled', true);
            $previewElement.css('border', '2px solid red');
            return;
        }

        const reader = new FileReader();
        reader.onload = function (e) {
            $previewElement.attr('src', e.target.result);
            $previewElement.css('border', '');
            if ($submitBtn) $submitBtn.prop('disabled', false);
            $('.text-danger.small').fadeOut(500);
        };
        reader.readAsDataURL(file);
    }

    // Attach delegated listeners to $(document) so they persist across Turbo renders
    // and don't need to be re-bound every time.
    function initDelegatedListeners() {
        const doc = $(document);

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
            const file = e.target.files[0];
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
    
    // For things that still need to run on every load (like timers)
    function runOnEveryLoad() {
        if ($('#image-preview').length) {
            // Auto-hide alert messages (flashes) and errors after 5 seconds
            setTimeout(function() {
                $('.alert, .text-danger.small').fadeOut(1000);
            }, 5000);
        }
    }

    $(document).on('turbo:load', runOnEveryLoad);
    $(document).on('turbo:render', runOnEveryLoad);
    $(document).on('DOMContentLoaded', runOnEveryLoad);
})();
