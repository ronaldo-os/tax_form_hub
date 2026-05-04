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
            stateSave: true,
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

    // Tab persistence and table adjustment
    $('button[data-bs-toggle="tab"]').off('shown.bs.tab.client').on('shown.bs.tab.client', function (e) {
        const targetId = $(e.target).attr('id');
        sessionStorage.setItem('activeClientSubmissionsTabId', targetId);
        tables.forEach(function (table) {
            table.columns.adjust().responsive.recalc();
        });
    });

    const activeTabId = sessionStorage.getItem('activeClientSubmissionsTabId');
    if (activeTabId && document.getElementById(activeTabId)) {
        const tabEl = document.getElementById(activeTabId);
        if (tabEl) {
            const tabTrigger = bootstrap.Tab.getOrCreateInstance(tabEl);
            tabTrigger.show();
        }
    }

    // Show file previews (thumbnails for images, icons for PDFs)
    function updateFileList(inputSelector, listSelector, multiple = true) {
        $(document).off('change', inputSelector).on('change', inputSelector, function () {
            const $input = $(this);
            const $list = $(listSelector).empty();
            const files = Array.from(this.files);

            if (!files.length) return;

            // Check for HEIC files
            const heicExtensions = ['.heic', '.heif'];
            const heicMimeTypes = ['image/heic', 'image/heif'];
            const invalidFiles = files.filter(file => {
                const ext = file.name.toLowerCase().substring(file.name.lastIndexOf('.'));
                return heicExtensions.includes(ext) || heicMimeTypes.includes(file.type.toLowerCase());
            });

            if (invalidFiles.length > 0) {
                const fileNames = invalidFiles.map(f => f.name).join(', ');
                if (window.showFlashMessage) {
                    window.showFlashMessage(`HEIC files are not supported: ${fileNames}<br>Please convert to JPG, PNG, or PDF.`, 'danger');
                }
                $input.val('');
                return;
            }

            const displayFiles = multiple ? files : [files[0]];
            
            // For single file, use full width; for multiple, use grid layout
            if (!multiple && displayFiles.length === 1) {
                $list.addClass('file-preview-single');
            } else {
                $list.addClass('file-preview-grid');
            }
            
            displayFiles.forEach(file => {
                const isImage = file.type.startsWith('image/');
                const isPDF = file.type === 'application/pdf';
                let previewHTML = '';

                if (isImage) {
                    // Create object URL for image preview
                    const objectUrl = URL.createObjectURL(file);
                    previewHTML = `
                        <li class="list-group-item file-preview-item p-0 border-0">
                            <div class="file-preview-container">
                                <img src="${objectUrl}" alt="${file.name}" class="file-preview-image" title="${file.name}">
                                <div class="file-preview-name">${file.name}</div>
                            </div>
                        </li>
                    `;
                } else if (isPDF) {
                    previewHTML = `
                        <li class="list-group-item file-preview-item p-3 border-0 d-flex flex-column align-items-center justify-content-center bg-light rounded">
                            <i class="bi bi-file-earmark-pdf fs-2 text-danger mb-2"></i>
                            <span class="file-preview-name text-center small" title="${file.name}">${file.name}</span>
                        </li>
                    `;
                } else {
                    // Fallback for other file types
                    previewHTML = `
                        <li class="list-group-item file-preview-item p-3 border-0 d-flex flex-column align-items-center justify-content-center bg-light rounded">
                            <i class="bi bi-file-earmark fs-2 text-secondary mb-2"></i>
                            <span class="file-preview-name text-center small" title="${file.name}">${file.name}</span>
                        </li>
                    `;
                }
                
                $list.append(previewHTML);
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
                                `<option value="${invoice.id}">${invoice.display_name}</option>`
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

// Listen for theme changes and update modal file inputs
document.addEventListener('theme:changed', function(e) {
    // Update file inputs in submitDocsModal
    const modalFileInputs = document.querySelectorAll('#submitDocsModal .file-upload-input, #submitDocsModal input[type="file"]');
    modalFileInputs.forEach(input => {
        // Force style recalculation
        const className = input.className;
        input.className = '';
        input.className = className;
        
        // Force CSS variable updates
        input.style.setProperty('background-color', '');
        input.style.setProperty('color', '');
        input.style.setProperty('border-color', '');
    });
});

document.addEventListener("turbo:load", initClientSubmissionsPage);
document.addEventListener("DOMContentLoaded", initClientSubmissionsPage);

// Init immediately to catch late-loading scripts
initClientSubmissionsPage();
