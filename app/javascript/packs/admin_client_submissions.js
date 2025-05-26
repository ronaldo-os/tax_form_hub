import $ from "jquery";
import "datatables.net-bs5";
import "datatables.net-bs5/css/dataTables.bootstrap5.min.css";

$(document).ready(function() {
    if ($('#taxSubmissionsTable').length) {
        $('#taxSubmissionsTable').DataTable({
            paging: true,
            searching: true,
            info: true,
            lengthChange: true,
        });
    }

    $('.auto-submit').on('change', function () {
        $(this).closest('form').submit();
    });
});
