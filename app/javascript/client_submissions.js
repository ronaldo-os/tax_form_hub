if (window.location.pathname.includes("")) {
    $(document).ready(function () {
        $('.submissionsTable').each(function () {
            $(this).DataTable({
            paging: true,
            searching: true,
            ordering: true,
            order: [[5, 'desc']] // order by 6th column (Date Submitted)
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
