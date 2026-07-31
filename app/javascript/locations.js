function fixEmptyRowColspan(api) {
    const table = api.table().node();
    const $emptyCell = $(table).find('td.dataTables_empty');
    if ($emptyCell.length) {
        const totalCols = $(table).find('thead tr:first-child th').length;
        if (totalCols > 0) {
            $emptyCell.attr('colspan', totalCols);
        }
    }
}

function initLocationsPage() {
    if (!window.location.pathname.includes("/locations")) return;

    const $table = $('#location-table').DataTable({
        responsive: true,
        autoWidth: false,
        destroy: true,
        language: {
            search: "_INPUT_",
            searchPlaceholder: "Search locations...",
            lengthMenu: "_MENU_",
            info: "Showing _START_-_END_ of _TOTAL_ locations",
            infoEmpty: "Showing 0-0 of 0 locations",
            paginate: {
                previous: '<i class="fa-solid fa-chevron-left"></i>',
                next: '<i class="fa-solid fa-chevron-right"></i>'
            }
        },
        initComplete: function () {
            const api = this.api();
            const $container = $(api.table().container());

            // Remove "Show _ entries" and "Search:" labels
            $container.find('div.dataTables_length label').contents().filter(function () {
                return this.nodeType === 3;
            }).remove();

            $container.find('div.dataTables_filter label').contents().filter(function () {
                return this.nodeType === 3;
            }).remove();

            // Setup filter bar container around dataTables_length
            const $lengthDiv = $container.find('div.dataTables_length');
            $lengthDiv.addClass('custom-filter-bar d-flex flex-wrap align-items-center gap-2');

            // Find column indices by header text
            const headers = api.columns().header().toArray();
            const typeColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('type'));
            const companyColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('company'));

            // Create Type Filter Select if Type column exists
            if (typeColIdx !== -1 && !$container.find('.custom-type-filter').length) {
                const $typeSelect = $('<select class="form-select form-select-sm custom-type-filter"><option value="">All Types</option></select>');

                const typeSet = new Set();
                api.column(typeColIdx).data().each(function (d) {
                    const cleanText = $('<div>').html(d).text().trim();
                    if (cleanText && cleanText !== 'N/A') {
                        typeSet.add(cleanText);
                    }
                });

                Array.from(typeSet).sort().forEach(function (t) {
                    $typeSelect.append(`<option value="${t}">${t}</option>`);
                });

                $typeSelect.on('change', function () {
                    const val = $(this).val();
                    if (val) {
                        api.column(typeColIdx).search('^' + $.fn.dataTable.util.escapeRegex(val) + '$', true, false).draw();
                    } else {
                        api.column(typeColIdx).search('').draw();
                    }
                });

                $lengthDiv.append($typeSelect);
            }

            // Create Company Filter Select if Company column exists
            if (companyColIdx !== -1 && !$container.find('.custom-company-filter').length) {
                const $companySelect = $('<select class="form-select form-select-sm custom-company-filter"><option value="">All Companies</option></select>');

                const companySet = new Set();
                api.column(companyColIdx).data().each(function (d) {
                    const cleanText = $('<div>').html(d).text().trim();
                    if (cleanText && cleanText !== 'N/A') {
                        companySet.add(cleanText);
                    }
                });

                Array.from(companySet).sort().forEach(function (comp) {
                    $companySelect.append(`<option value="${comp}">${comp}</option>`);
                });

                $companySelect.on('change', function () {
                    const val = $(this).val();
                    if (val) {
                        api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(val) + '$', true, false).draw();
                    } else {
                        api.column(companyColIdx).search('').draw();
                    }
                });

                $lengthDiv.append($companySelect);
            }
        },
        drawCallback: function () {
            const api = this.api();
            fixEmptyRowColspan(api);
        }
    });

    // Fix empty row colspan on draw and resize
    $table.on('draw.dt responsive-resize.dt', function () {
        fixEmptyRowColspan($table);
    });

    const $form = $('#locationModal form');

    const resetForm = (action = '/locations', method = null) => {
        $form[0].reset();
        $form.attr('action', action);
        $form.find('input[name="_method"]').remove();
        if (method) {
            $form.append(`<input type="hidden" name="_method" value="${method}">`);
        }
    };

    // Handle Add (dropdown option click)
    $(document).off('click.location-option').on('click.location-option', '.location-option', function (e) {
        e.preventDefault();
        const type = $(this).data('location-type');
        resetForm();
        $('#locationModalLabel').text(`Create a new ${type.toLowerCase()} location`);
        $('#modal_location_type').val(type);
    });

    // Handle Edit
    $(document).off('click.edit-location').on('click.edit-location', '.edit-location', function (e) {
        e.preventDefault();
        const loc = $(this).data();
        resetForm(`/locations/${loc.id}`, 'patch');

        $('#locationModalLabel').text(`Edit ${loc.locationType} Location`);
        $('#modal_location_type').val(loc.locationType);
        $('#location_location_name').val(loc.locationName);
        $('#location_country').val(loc.country);
        $('#location_company_name').val(loc.companyName);
        $('#location_tax_number').val(loc.taxNumber);
        $('#location_post_box').val(loc.postBox);
        $('#location_street').val(loc.street);
        $('#location_building').val(loc.building);
        $('#location_additional_street').val(loc.additionalStreet);
        $('#location_zip_code').val(loc.zipCode);
        $('#location_city').val(loc.city);

        new bootstrap.Modal('#locationModal').show();
    });

    // Form success (ajax:success for Turbo / Rails UJS)
    $form.off('ajax:success').on('ajax:success', function () {
        $('#locationModal').modal('hide');
        $table.ajax.reload(null, false);
        this.reset();
    });

    // Form error
    $form.off('ajax:error').on('ajax:error', function () {
        showFlashMessage("Failed to save location.", "danger");
    });
}

document.addEventListener("turbo:load", initLocationsPage);
document.addEventListener("DOMContentLoaded", initLocationsPage);

// Init immediately to catch late-loading scripts
initLocationsPage();
