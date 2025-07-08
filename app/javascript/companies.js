if (window.location.pathname.includes("/companies")) {
    $(document).ready(function () {
        function updateLabel(selectId, labelId, defaultText) {
            $(selectId).on('change', function () {
                const text = $(this).val() ? $(this).find('option:selected').text() + ' Number' : defaultText;
                $(labelId).text(text);
            });
        }
        updateLabel('#company_id_type', '#company_id_number_label', '');
        updateLabel('#tax_id_type', '#tax_id_number_label', '');
    });
}
