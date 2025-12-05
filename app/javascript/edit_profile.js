if (window.location.pathname.includes("/profile/edit")) {
    $(document).ready(function () {
        const $imagePreview = $('#image-preview');
        const $fileInput = $('#profile_image_input');
        const $submitBtn = $('#update-profile-btn');
        const defaultImageSrc = $imagePreview.attr('src');

        // Trigger file input when clicking the image or overlay
        $('#image-preview-wrapper').on('click', function (e) {
            // Ignore clicks on the input itself or the label (which handles it natively)
            if ($(e.target).is($fileInput) || $(e.target).closest('label').length > 0) {
                return;
            }
            $fileInput.click();
        });

        // Prevent infinite loop by stopping propagation from the input itself
        $fileInput.on('click', function (e) {
            e.stopPropagation();
        });

        $fileInput.on('change', function (e) {
            const file = e.target.files[0];

            // Reset state
            $submitBtn.prop('disabled', false);
            $imagePreview.css('border', '');

            if (file) {
                if (!file.type.startsWith('image/')) {
                    alert("Please select a valid image file.");
                    $submitBtn.prop('disabled', true);
                    $imagePreview.css('border', '2px solid red');
                    e.target.value = ""; // Clear the input
                    return;
                }

                const reader = new FileReader();

                reader.onload = function (e) {
                    $imagePreview.attr('src', e.target.result);
                };

                reader.onerror = function () {
                    alert("Failed to read the file. Please try another one.");
                    $submitBtn.prop('disabled', true);
                    $imagePreview.attr('src', defaultImageSrc); // Revert to original
                    e.target.value = ""; // Clear input
                };

                reader.readAsDataURL(file);
            }
        });
    });
}
