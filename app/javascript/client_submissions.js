if (window.location.pathname === "/") {
    $(document).ready(function () {
        const tables = [];

        $('.submissionsTable').each(function () {
        const table = $(this).DataTable({
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
            }
        });

        tables.push(table);
        });

        $('a[data-bs-toggle="tab"]').on('shown.bs.tab', function () {
            tables.forEach(function (table) {
                table.columns.adjust().responsive.recalc();
            });
        });

        // Show the selected file and its size in a list format
        $(function () {
            function updateFileList(inputSelector, listSelector, multiple = true) {
                $(inputSelector).on('change', function () {
                    const $list = $(listSelector).empty();
                    const files = Array.from(this.files);

                    if (!files.length) return;

                    const displayFiles = multiple ? files : [files[0]];
                    displayFiles.forEach(file => {
                    const size = Math.round(file.size / 1024);
                    $list.append(`
                        <li class="list-group-item d-flex justify-content-between align-items-center">
                        ${file.name}
                        <span class="badge bg-secondary rounded-pill">${size} KB</span>
                        </li>
                    `);
                    });
                });
            }

            updateFileList('#deposit_slip_input', '#deposit_slip_list', true);
            updateFileList('#form_2307_input', '#form_2307_list', false);
        });

        const params = new URLSearchParams(window.location.search);
        const submissionId = params.get("open_submission");

        if (submissionId) {
            const modal = new bootstrap.Modal($("#submissionModal")[0]);
            modal.show();

            $.ajax({
            url: "tax_submissions/" + submissionId,
            dataType: "script",
            headers: { Accept: "text/javascript" }
            });
        }
    });
}
