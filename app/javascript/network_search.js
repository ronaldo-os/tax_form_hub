let timeout = null;

$(document).on('input', '#company_search_input', function () {
    const $searchForm = $('#network_search_form');

    if ($searchForm.length) {
        clearTimeout(timeout);

        timeout = setTimeout(function () {
            if ($searchForm[0].requestSubmit) {
                $searchForm[0].requestSubmit();
            } else {
                $searchForm.submit();
            }
        }, 50);
    }
});
