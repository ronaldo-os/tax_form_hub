if (window.location.pathname.includes("/admin/tax_submissions")) {
    $(document).ready(function () {
        ['#taxSubmissionsTableActive', '#taxSubmissionsTableArchived'].forEach(function (id) {
            if ($(id).length) {
                $(id).DataTable({
                responsive: true,
                paging: true,
                searching: true,
                info: true,
                lengthChange: true,
                pageLength: 10,
                language: {
                    search: "_INPUT_",
                    searchPlaceholder: "Search submissions...",
                    lengthMenu: "Show _MENU_ entries",
                },
                });
            }
        });


        $('.auto-submit').on('change', function () {
            $(this).closest('form').submit();
        });

        $('.zoom-link').on('click', function (e) {
            e.preventDefault();
            const imgUrl = $(this).data('img-url');
            $('#modalImage').attr('src', imgUrl);

            const myModal = new bootstrap.Modal(document.getElementById('imageModal'));
            myModal.show();
        });
    });
}
