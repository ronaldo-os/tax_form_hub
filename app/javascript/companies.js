function initCompanyPage() {
    if (!window.location.pathname.includes("/companies")) {
        return;
    }

    const $companyForm = $('form[action*="/companies"]');
    if ($companyForm.length === 0 && !window.location.pathname.endsWith("/new")) {
        return;
    }

    // Ensure form action URL is correct (fix for Turbo cache issue)
    if ($companyForm.length > 0) {
        const currentPath = window.location.pathname;
        const formAction = $companyForm.attr('action');
        // If form action doesn't match current path, update it
        if (formAction && !formAction.includes(currentPath)) {
            $companyForm.attr('action', currentPath);
        }
        
        // Ensure form can be submitted (fix for cache issue)
        $companyForm.off('submit.companySubmit').on('submit.companySubmit', function(e) {
            console.log('Form submit triggered');
            // Allow the form to submit normally
            return true;
        });
        
        // Debug: Check form state
        console.log('Company form found:', $companyForm.length > 0);
        console.log('Form action:', $companyForm.attr('action'));
        console.log('Form method:', $companyForm.attr('method'));
        console.log('Submit button:', $('#update-company-btn').length > 0);
        console.log('Submit button disabled:', $('#update-company-btn').prop('disabled'));
    }

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

        $select.off("change.companyLabel").on("change.companyLabel", setLabel);
        setLabel();
    }

    updateLabel('#company_id_type', '#company_id_number_label', 'Company ID Number');
    updateLabel('#tax_id_type', '#tax_id_number_label', 'Tax ID Number');

    const $imagePreview = $('#image-preview');
    const $fileInput = $('#profile_image_input');
    const $submitBtn = $('#update-company-btn');
    const defaultImageSrc = $imagePreview.attr('src');
    const $imagePreviewWrapper = $('#image-preview-wrapper');

    $imagePreviewWrapper.off('click.companyImg').on('click.companyImg', function (e) {
        if ($(e.target).is($fileInput) || $(e.target).closest('label').length > 0) {
            return;
        }
        $fileInput.trigger('click');
    });

    $fileInput.off('change.companyInput').on('change.companyInput', function (e) {
        const file = e.target.files && e.target.files[0];
        if (!file) {
            return;
        }

        if (!file.type.startsWith('image/')) {
            alert('Please select a valid image file.');
            $submitBtn.prop('disabled', true);
            $imagePreview.css('border', '2px solid red');
            e.target.value = '';
            return;
        }

        const reader = new FileReader();
        reader.onload = function (loadEvent) {
            $imagePreview.attr('src', loadEvent.target.result);
        };
        reader.onerror = function () {
            alert('Failed to read the file. Please try another one.');
            $imagePreview.attr('src', defaultImageSrc);
            e.target.value = '';
        };
        reader.readAsDataURL(file);
    });

    $("#recommend-btn").off("click.companyRec").on("click.companyRec", function (e) {
        e.preventDefault();
        showFlashMessage("You are currently in visitor view and can't write a recommendation for your own company.", "danger");
    });

    // Map rendering logic
    renderCompanyMap();
}

function renderCompanyMap() {
    var rawAddress = $('#company_location_text').text().trim();
    var $mapFrame = $('#map-frame');
    var $errorBox = $('#map-error');

    if ($mapFrame.length === 0) return; // Exit if no map frame (e.g. maybe on new page or different view)

    if (!rawAddress || rawAddress === 'N/A' || rawAddress === 'None') {
        $errorBox.text('No company address provided.').show();
        $mapFrame.hide();
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
            .done(function (data) {
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
            .fail(function () {
                // Try next fallback level on error
                tryGeocode(level + 1);
            });
    }

    // Start searching
    tryGeocode(0);
}

// Bind to Turbo Load
document.addEventListener("turbo:load", initCompanyPage);
document.addEventListener("DOMContentLoaded", initCompanyPage);
if (document.readyState !== "loading") {
  initCompanyPage();
}

// Ensure form is properly functional after being restored from cache
document.addEventListener("turbo:render", function() {
  if (window.location.pathname.includes("/companies")) {
    const $submitBtn = $('#update-company-btn');
    if ($submitBtn) {
      $submitBtn.prop('disabled', false);
    }
    
    // Re-initialize the company page to ensure all event listeners are attached
    initCompanyPage();
  }
});
