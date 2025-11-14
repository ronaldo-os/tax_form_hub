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

        // Map rendering logic

        var rawAddress = $('#company_location_text').text().trim();
        var $mapFrame = $('#map-frame');
        var $errorBox = $('#map-error');

        if (!rawAddress || rawAddress === 'N/A') {
            $errorBox.text('No company address provided.').show();
            return;
        }

        // STEP 1 — remove unit numbers
        var address = rawAddress.replace(/^(unit\s*\d+|[A-Za-z]+\s*\d+|\d+[A-Za-z]?|\w+\s*\d+)\s+/i, '').trim();

        // STEP 2 — remove leading digits
        address = address.replace(/^\d+\s+/i, '').trim();

        console.log("Level 1 Cleaned:", address);

        var parts = address.split(',');
        parts = parts.map(p => p.trim());

        var fallbackLevels = [];

        // Level 1 — Full address
        fallbackLevels.push(address);

        // Level 2 — remove first part (building name)
        if (parts.length >= 3) {
            fallbackLevels.push(parts.slice(1).join(', ')); 
        }

        // Level 3 — street + city only
        if (parts.length >= 3) {
            fallbackLevels.push(parts.slice(-2).join(', ')); 
        }

        // Level 4 — city only
        fallbackLevels.push(parts[parts.length - 1]);

        console.log("Fallback Levels:", fallbackLevels);

        // Recursive search
        function tryGeocode(level) {
            if (level >= fallbackLevels.length) {
                $errorBox.text('Address not found. Please check the company address.').show();
                $mapFrame.hide();
                return;
            }

            var query = fallbackLevels[level];
            console.log("Trying level", level, "→", query);

            $.getJSON('https://nominatim.openstreetmap.org/search?format=json&limit=1&q=' + encodeURIComponent(query))
                .done(function(data) {
                    console.log("Response level", level, data);

                    if (data && data.length > 0) {
                        var lat = parseFloat(data[0].lat);
                        var lon = parseFloat(data[0].lon);

                        var bbox = (lon - 0.01) + ',' + (lat - 0.01) + ',' +
                                (lon + 0.01) + ',' + (lat + 0.01);

                        var mapSrc = 'https://www.openstreetmap.org/export/embed.html?bbox=' +
                                    bbox + '&layer=mapnik&marker=' + lat + ',' + lon;

                        $mapFrame.attr('src', mapSrc).show();
                        $errorBox.hide();
                    } else {
                        // Try next fallback level
                        tryGeocode(level + 1);
                    }
                })
                .fail(function() {
                    // Try next fallback level on error
                    tryGeocode(level + 1);
                });
        }

        // Start searching
        tryGeocode(0);

    });
}
