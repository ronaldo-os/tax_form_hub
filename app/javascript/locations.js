if (window.location.pathname.includes("/locations")) {
    $(function () {
        const $table = $('#location-table').DataTable();
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
        $('.location-option').on('click', function () {
            const type = $(this).data('location-type');
            resetForm();
            $('#locationModalLabel').text(`Create a new ${type.toLowerCase()} location`);
            $('#modal_location_type').val(type);
        });

        // Handle Edit
        $('.edit-location').on('click', function () {
            const loc = $(this).data();
            resetForm(`/locations/${loc.id}`, 'patch');

            $('#locationModalLabel').text(`Edit ${loc.locationType} Location`);
            $('#modal_location_type').val(loc.locationType);
            $('#location_name').val(loc.locationName);
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
        $form.on('ajax:success', function () {
            $('#locationModal').modal('hide');
            $table.ajax.reload(null, false);
            this.reset();
        });

        // Form error
        $form.on('ajax:error', function () {
            alert("Failed to save location.");
        });
    });
}
