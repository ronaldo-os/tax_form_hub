function initClientSubmissionsPage() {
    // This script targets the home page where the user can submit documents
    // The path is strictly "/" for now based on previous code, but let's check for home
    if (window.location.pathname !== "/" && !window.location.pathname.includes("/tax_submissions/home")) {
        return;
    }

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
            destroy: true,
            initComplete: function () {
                const api = this.api();
                const $container = $(api.table().container());

                // Remove "Show _ entries" and "Search:" labels
                $container.find('div.dataTables_length label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();

                $container.find('div.dataTables_filter label').contents().filter(function () {
                    return this.nodeType === 3;
                }).remove();
            }
        });

        tables.push(table);
    });

    $('a[data-bs-toggle="tab"]').off('shown.bs.tab.client').on('shown.bs.tab.client', function () {
        tables.forEach(function (table) {
            table.columns.adjust().responsive.recalc();
        });
    });

    // Show the selected file and its size in a list format
    function updateFileList(inputSelector, listSelector, multiple = true) {
        $(document).off('change', inputSelector).on('change', inputSelector, function () {
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


    const params = new URLSearchParams(window.location.search);
    const submissionId = params.get("open_submission");

    if (submissionId) {
        const modalElement = document.getElementById("submissionModal");
        if (modalElement) {
            const modal = new bootstrap.Modal(modalElement);
            modal.show();

            $.ajax({
                url: "tax_submissions/" + submissionId,
                dataType: "script",
                headers: { Accept: "text/javascript" }
            });
        }
    }

    // Fetch invoices based on selected company
    $(document).off("change", "#company_select").on("change", "#company_select", function () {
        const companyId = $(this).val();
        const $invoiceSelect = $("#invoice_select");

        // Clear and show loading state
        $invoiceSelect.empty().append('<option value="">Loading invoices...</option>').prop('disabled', true);

        if (companyId) {
            $.ajax({
                url: "/tax_submissions/fetch_invoices",
                data: { company_id: companyId },
                dataType: "json",
                success: function (data) {
                    $invoiceSelect.empty().append('<option value="">Select Invoice</option>');

                    if (data.length === 0) {
                        $invoiceSelect.append('<option value="" disabled>No invoices available for this company</option>');
                    } else {
                        data.forEach(function (invoice) {
                            $invoiceSelect.append(
                                `<option value="${invoice.id}">${invoice.invoice_number}</option>`
                            );
                        });
                    }
                    $invoiceSelect.prop('disabled', false);
                },
                error: function (xhr, status, error) {
                    console.error("Error fetching invoices:", error);
                    $invoiceSelect.empty().append('<option value="" disabled>Error loading invoices. Please try again.</option>');
                    $invoiceSelect.prop('disabled', false);

                    // Show user-friendly alert
                    alert("Unable to load invoices. Please refresh the page and try again.");
                }
            });
        } else {
            $invoiceSelect.empty().append('<option value="">Select Invoice</option>').prop('disabled', false);
        }
    });

    // Reopen modal if there are errors
    if ($("#has_submission_errors").val() === "true") {
        const modalEl = document.getElementById("submitDocsModal");
        if (modalEl) {
            const submitModal = new bootstrap.Modal(modalEl);
            submitModal.show();
        }
    }

    // Form validation before submission
    $(document).off("submit", "#submitDocsModal form").on("submit", "#submitDocsModal form", function (e) {
        const companyId = $("#company_select").val();
        const invoiceId = $("#invoice_select").val();

        if (!companyId) {
            e.preventDefault();
            alert("Please select a company before submitting.");
            return false;
        }

        if (!invoiceId) {
            e.preventDefault();
            alert("Please select an invoice number before submitting. If no invoices are available, please create an invoice first.");
            return false;
        }

        return true;
    });
}

document.addEventListener("turbo:load", initClientSubmissionsPage);
document.addEventListener("DOMContentLoaded", initClientSubmissionsPage);

// Init immediately to catch late-loading scripts
initClientSubmissionsPage();
