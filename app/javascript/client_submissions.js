if (window.location.pathname.includes("")) {
    $(document).ready(function () {
        $('.submissionsTable').each(function () {
            $(this).DataTable({
                responsive: true,
                paging: true,
                searching: true,
                ordering: true,
                order: [[5, 'desc']],
                pageLength: 10,
                lengthChange: true,
                language: {
                search: "_INPUT_",
                searchPlaceholder: "Search submissions...",
                lengthMenu: "Show _MENU_ entries",
                },
            });
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
