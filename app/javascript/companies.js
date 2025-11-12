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
            showFlashMessage("You are currently in visitor view and can't write a recommendation for your own company.", "danger");
        });

        var address = $('#company_location_text').text().trim();
        var $mapFrame = $('#map-frame');
        var $errorBox = $('#map-error');

        if (!address || address === 'N/A') {
        $errorBox.text('No company address provided.').show();
        return;
        }

        var query = encodeURIComponent(address);
        var url = 'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=' + query;

        $.getJSON(url)
        .done(function(data) {
            if (data && data.length > 0) {
            var lat = parseFloat(data[0].lat);
            var lon = parseFloat(data[0].lon);

            // Compute a small bbox for map view
            var bbox = (lon - 0.01) + ',' + (lat - 0.01) + ',' + (lon + 0.01) + ',' + (lat + 0.01);
            var mapSrc = 'https://www.openstreetmap.org/export/embed.html?bbox=' + bbox + '&layer=mapnik&marker=' + lat + ',' + lon;

            $mapFrame.attr('src', mapSrc);
            } else {
            $errorBox
                .text('Address not found. Please check the company address.')
                .show();
            $mapFrame.hide();
            }
        })
        .fail(function() {
            $errorBox
            .text('Error retrieving map data. Please check your connection or try again later.')
            .show();
            $mapFrame.hide();
        });
        });
}
