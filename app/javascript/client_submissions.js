if (window.location.pathname.includes("")) {
    $(document).ready(function () {
        $('#submissionsTable').DataTable({
            paging: true,
            searching: true,
            ordering:  true,
            order: [[1, "desc"]]  // order by upload date desc by default
        });
    });
}
