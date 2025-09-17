if (window.location.pathname.includes("/companies")) {
    $(document).ready(function () {

        function updateLabel(selectId, labelId, defaultText) {
            var $select = $(selectId);
            var $label = $(labelId);

            function setLabel() {
                var selectedText = $select.find("option:selected").text();
                if (selectedText) {
                    $label.text(selectedText + " Number");
                } else {
                    $label.text(defaultText);
                }
            }

            $select.on("change", setLabel);
            setLabel();
        }

        updateLabel('#company_id_type', '#company_id_number_label', 'Company ID Number');
        updateLabel('#tax_id_type', '#tax_id_number_label', 'Tax ID Number');

        $('#image-preview').on('click', function () {
            $('#profile_image_input').click();
        });

        $('#profile_image_input').on('change', function (e) {
            const file = e.target.files[0];
            if (file && file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = function (e) {
                    $('#image-preview').attr('src', e.target.result);
                };
                reader.readAsDataURL(file);
            }
        });

        $("#recommend-btn").on("click", function (e) {
            e.preventDefault();

            $('.custom_tfh_alert').remove();

            const flashHtml = `
            <div class="custom_tfh_alert alert alert-dismissible show d-flex align-items-start" role="alert">
                <i class="fa-solid fa-circle-exclamation me-2 mt-1 alert_text_danger"></i>
                <div>
                <h5 class="mb-1">Notice:</h5>
                <span>You are currently in visitor view and can't write a recommendation for your own company</span>
                </div>
            </div>
            `;

            $('body').prepend(flashHtml);

            setTimeout(() => $('.custom_tfh_alert').fadeOut(300, function() { $(this).remove(); }), 5000);
        });
    });
}
