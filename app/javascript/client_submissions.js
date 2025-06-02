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
    });
}
