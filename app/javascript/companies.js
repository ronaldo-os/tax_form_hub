if (window.location.pathname.includes("/companies")) {
    $(document).ready(function () {
        $('#companies-table').DataTable({
            responsive: true,
            pageLength: 10,
            columnDefs: [
                { orderable: false, targets: -1 }
            ]
        });
    });

    // Handle Add New Company button
    $('#add-new-company-btn').on('click', function () {
      $('#companyModalLabel').text("Add New Company");
      $('#company-form').attr('action', '/companies');
      $('#form-method-field').val('post');

      // Clear form fields
      $('#company_name, #company_number, #tax_number, #country, #address_line1, #address_line2, #address_line3, #zip_city').val('');
    });

    // Edit button handler
    $('.edit-company-btn').on('click', function () {
        const $btn = $(this);

        $('#companyModalLabel').text("Edit Company");
        $('#company-form').attr('action', $btn.data('url'));
        $('#form-method-field').val('patch');

        $('#company_name').val($btn.data('name'));
        $('#company_number').val($btn.data('company-number'));
        $('#tax_number').val($btn.data('tax-number'));
        $('#country').val($btn.data('country'));
        $('#address_line1').val($btn.data('address-line1'));
        $('#address_line2').val($btn.data('address-line2'));
        $('#zip_code').val($btn.data('zip-code'));
        $('#city').val($btn.data('city'));
        });

    // View button handler
    $('.view-company-btn').on('click', function () {
        const $btn = $(this);

        $('#view_name').text($btn.data('name'));
        $('#view_company_number').text($btn.data('company-number'));
        $('#view_tax_number').text($btn.data('tax-number'));
        $('#view_address_line1').text($btn.data('address-line1'));
        $('#view_address_line2').text($btn.data('address-line2'));

        const zip = $btn.data('zip-code');
        const city = $btn.data('city');
        $('#view_zip_code_city').text(`${zip} ${city}`);
        $('#view_country').text($btn.data('country'));

    });




}
