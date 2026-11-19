import { exportSubmissionsToCsv } from './tax_submissions_export';
import { setupTaxSubmissionsBulkActions } from './tax_submissions_bulk';
import { getInitialTableState, updateUrlParams, activateTabElement, bindSearchInputSync, bindPaginationSync, resolveSortOrder, bindOrderSync } from './table_url_sync';
import { hideSkeleton, setupSkeletonSafetyFallback } from './skeleton_loader';

function fixEmptyRowColspan(tableApi) {
    if (!tableApi) return;
    const $table = $(tableApi.table().node());
    const totalCols = $table.find('thead tr:first-child th').length || tableApi.columns().count();
    if (totalCols) {
        $table.find('tbody td.dataTables_empty').attr('colspan', totalCols);
    }
}

export function syncTaxSubmissionRedirectUrl() {
    const $redirectInput = $('#tax_submission_redirect_url');
    if ($redirectInput.length === 0) return;

    try {
        const url = new URL(window.location.href);
        url.searchParams.delete('open_modal');
        url.searchParams.delete('open_submit_modal');
        url.searchParams.delete('invoice_id');
        url.searchParams.delete('company_id');
        const targetUrl = url.pathname + (url.search ? url.search : '');
        if (targetUrl) {
            $redirectInput.val(targetUrl);
        }
    } catch (e) {
        // Fallback to existing server-rendered value
    }
}

function initClientSubmissionsPage() {
    setupSkeletonSafetyFallback([['tax_submissions_skeleton', 'tax_submissions_content']]);

    // This script targets the home page where the user can submit documents
    if ($('.submissionsTable').length === 0 && $('#submitDocsModal').length === 0) {
        hideSkeleton('tax_submissions_skeleton', 'tax_submissions_content');
        return;
    }

    const initial = getInitialTableState();

    // Tab restoration based on URL parameter or sessionStorage fallback
    if (initial.tab === 'archived') {
        const archivedTab = document.getElementById('archived-tab');
        if (archivedTab) {
            activateTabElement(archivedTab);
            sessionStorage.setItem('activeClientSubmissionsTabId', 'archived-tab');
        }
    } else if (initial.tab === 'active' || initial.tab === 'unarchived') {
        const activeTab = document.getElementById('unarchived-tab') || document.getElementById('active-tab');
        if (activeTab) {
            activateTabElement(activeTab);
            sessionStorage.setItem('activeClientSubmissionsTabId', activeTab.id);
        }
    } else {
        const savedTabId = sessionStorage.getItem('activeClientSubmissionsTabId');
        if (savedTabId && document.getElementById(savedTabId)) {
            const tabEl = document.getElementById(savedTabId);
            if (tabEl) {
                activateTabElement(tabEl);
                const isArchived = savedTabId === 'archived-tab';
                updateUrlParams({ tab: isArchived ? 'archived' : 'active' });
            }
        }
    }

    const tables = [];

    $('.submissionsTable').each(function () {
        if ($.fn.DataTable.isDataTable(this)) {
            const table = $(this).DataTable();
            tables.push(table);
            setupTaxSubmissionsBulkActions(table, $(this).attr('id'));
            return;
        }

        const defaultOrder = [[8, 'desc']];
        const resolvedOrder = resolveSortOrder($(this), initial.sort, initial.dir, defaultOrder);

        const table = $(this).DataTable({
            responsive: true,
            paging: true,
            searching: true,
            ordering: true,
            order: resolvedOrder,
            columnDefs: [
                { orderable: false, targets: [0, -2, -1] }
            ],
            pageLength: 25,
            displayStart: initial.page > 1 ? (initial.page - 1) * 25 : 0,
            lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
            lengthChange: true,
            language: {
                search: "_INPUT_",
                searchPlaceholder: "Search submissions...",
                lengthMenu: "_MENU_",
                info: "Showing _START_-_END_ of _TOTAL_ submissions",
                infoEmpty: "Showing 0-0 of 0 submissions",
                paginate: {
                    previous: '<i class="fa-solid fa-chevron-left"></i>',
                    next: '<i class="fa-solid fa-chevron-right"></i>'
                }
            },
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

                // Setup filter bar container around dataTables_length
                const $lengthDiv = $container.find('div.dataTables_length');
                $lengthDiv.find('select').addClass('form-select form-select-sm');
                $lengthDiv.addClass('custom-filter-bar d-flex flex-wrap align-items-center gap-2');

                // Find column indices by header text
                const headers = api.columns().header().toArray();
                const companyColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('company'));
                const statusColIdx = headers.findIndex(th => $(th).text().trim().toLowerCase().includes('status'));

                let needsRedraw = false;

                // Create Company Filter Select if company column exists
                if (companyColIdx !== -1 && !$container.find('.custom-company-filter').length) {
                    const $companySelect = $('<select class="form-select form-select-sm custom-company-filter"><option value="">All Companies</option></select>');

                    const companySet = new Set();
                    api.column(companyColIdx).data().each(function (d) {
                        const cleanText = $('<div>').html(d).text().trim();
                        if (cleanText && cleanText !== 'N/A') {
                            companySet.add(cleanText);
                        }
                    });

                    Array.from(companySet).sort().forEach(function (comp) {
                        $companySelect.append(`<option value="${comp}">${comp}</option>`);
                    });

                    $companySelect.on('change', function () {
                        const val = $(this).val();
                        updateUrlParams({ company: val || null }, { clearPage: true });
                        if (val) {
                            api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(val) + '$', true, false).draw();
                        } else {
                            api.column(companyColIdx).search('').draw();
                        }
                    });

                    $lengthDiv.append($companySelect);

                    if (initial.company) {
                        $companySelect.val(initial.company);
                        if ($companySelect.val() === initial.company) {
                            api.column(companyColIdx).search('^' + $.fn.dataTable.util.escapeRegex(initial.company) + '$', true, false);
                            needsRedraw = true;
                        }
                    }
                }

                // Create Status Filter Select if status column exists
                if (statusColIdx !== -1 && !$container.find('.custom-status-filter').length) {
                    const $statusSelect = $(`
                        <select class="form-select form-select-sm custom-status-filter">
                            <option value="">All Statuses</option>
                            <option value="Pending">Pending</option>
                            <option value="Processed">Processed</option>
                            <option value="Reviewed">Reviewed</option>
                            <option value="Processed & Reviewed">Processed & Reviewed</option>
                        </select>
                    `);

                    $statusSelect.on('change', function () {
                        const val = $(this).val();
                        updateUrlParams({ status: val || null }, { clearPage: true });
                        if (val) {
                            api.column(statusColIdx).search($.fn.dataTable.util.escapeRegex(val), true, false).draw();
                        } else {
                            api.column(statusColIdx).search('').draw();
                        }
                    });

                    $lengthDiv.append($statusSelect);

                    if (initial.status) {
                        $statusSelect.val(initial.status);
                        if ($statusSelect.val()) {
                            api.column(statusColIdx).search($.fn.dataTable.util.escapeRegex(initial.status), true, false);
                            needsRedraw = true;
                        }
                    }
                }

                // Append Export CSV button to custom filter bar
                if (!$container.find('.custom-export-csv-btn').length) {
                    const $exportBtn = $(`
                        <button type="button" class="btn btn-outline-secondary btn-sm custom-export-csv-btn d-inline-flex align-items-center gap-1.5" title="Export currently filtered records to CSV">
                            <i class="fa-solid fa-file-csv text-success"></i>
                            <span>Export CSV</span>
                        </button>
                    `);

                    $exportBtn.on('click', function (e) {
                        e.preventDefault();
                        const tabPane = $(api.table().node()).closest('.tab-pane');
                        const isArchived = tabPane.attr('id') === 'archived';
                        exportSubmissionsToCsv(api, isArchived ? 'tax_submissions_archived' : 'tax_submissions_active', false);
                    });

                    $lengthDiv.append($exportBtn);
                }

                // Search input synchronization
                const $searchInput = $container.find('div.dataTables_filter input');
                $searchInput.addClass('form-control form-control-sm');
                if (initial.search) {
                    $searchInput.val(initial.search);
                    api.search(initial.search);
                    needsRedraw = true;
                }
                bindSearchInputSync($searchInput);
                bindPaginationSync(api);
                bindOrderSync(api, { defaultOrder: defaultOrder });

                if (needsRedraw) {
                    api.draw(false);
                }

                hideSkeleton('tax_submissions_skeleton', 'tax_submissions_content');
            },
            drawCallback: function () {
                const api = this.api();
                fixEmptyRowColspan(api);
            }
        });

        $(table.table().node()).on('draw.dt responsive-resize.dt', function () {
            fixEmptyRowColspan(table);
        });

        tables.push(table);
        setupTaxSubmissionsBulkActions(table, $(this).attr('id'));
    });

    hideSkeleton('tax_submissions_skeleton', 'tax_submissions_content');

    // Tab persistence and table adjustment
    $('#submissionTabs button[data-bs-toggle="tab"]')
        .off('click.client shown.bs.tab.client')
        .on('click.client shown.bs.tab.client', function (e) {
            const targetId = $(e.currentTarget).attr('id') || '';
            const isArchived = targetId === 'archived-tab' || (targetId.includes('archived') && !targetId.includes('unarchived'));
            sessionStorage.setItem('activeClientSubmissionsTabId', targetId);
            updateUrlParams({ tab: isArchived ? 'archived' : 'active' });
            syncTaxSubmissionRedirectUrl();
            if (e.type === 'shown') {
                tables.forEach(function (table) {
                    table.columns.adjust().responsive.recalc();
                    fixEmptyRowColspan(table);
                    setTimeout(function() {
                        fixEmptyRowColspan(table);
                    }, 50);
                });
            }
        });

    // Show file previews (thumbnails for images, embeds for PDFs) and sync dropzone state
    function updateFileList(inputSelector, listSelector, multiple = true) {
        $(document).off('change.tax_dropzone', inputSelector).on('change.tax_dropzone', inputSelector, function () {
            const $input = $(this);
            const listEl = document.querySelector(listSelector);
            const $dropzone = $input.closest('.file-dropzone');

            if (listEl) {
                listEl.replaceChildren();
                listEl.classList.remove('file-preview-single', 'file-preview-grid');
            }

            const files = Array.from(this.files || []);
            if (!files.length) {
                $dropzone.removeClass('has-files is-dragover');
                $dropzone.find('.dropzone-status-text').remove();
                $dropzone.find('.dropzone-default-text').removeClass('d-none');
                return;
            }

            // Check for HEIC files
            const heicExtensions = ['.heic', '.heif'];
            const heicMimeTypes = ['image/heic', 'image/heif'];
            const invalidFiles = files.filter(file => {
                const dotIdx = file.name.lastIndexOf('.');
                const ext = dotIdx >= 0 ? file.name.toLowerCase().substring(dotIdx) : '';
                return heicExtensions.includes(ext) || heicMimeTypes.includes((file.type || '').toLowerCase());
            });

            if (invalidFiles.length > 0) {
                const fileNames = invalidFiles.map(f => f.name).join(', ');
                if (window.showFlashMessage) {
                    window.showFlashMessage(`HEIC files are not supported: ${fileNames}. Please convert to JPG, PNG, or PDF.`, 'danger');
                }
                $input.val('');
                $dropzone.removeClass('has-files is-dragover');
                $dropzone.find('.dropzone-status-text').remove();
                $dropzone.find('.dropzone-default-text').removeClass('d-none');
                return;
            }

            const displayFiles = multiple ? files : [files[0]];

            // Update dropzone UI state safely without innerHTML
            $dropzone.addClass('has-files');
            $dropzone.find('.dropzone-default-text').addClass('d-none');
            const countText = multiple
                ? `${displayFiles.length} file${displayFiles.length > 1 ? 's' : ''} selected`
                : `1 file selected (${displayFiles[0].name})`;

            let statusEl = $dropzone.find('.dropzone-status-text')[0];
            if (!statusEl) {
                statusEl = document.createElement('div');
                statusEl.className = 'dropzone-status-text text-success fw-semibold small mt-1';
                const contentEl = $dropzone.find('.dropzone-content')[0];
                if (contentEl) contentEl.appendChild(statusEl);
            }
            statusEl.replaceChildren();
            const checkIcon = document.createElement('i');
            checkIcon.className = 'fa-solid fa-circle-check me-1';
            statusEl.appendChild(checkIcon);
            statusEl.appendChild(document.createTextNode(countText));

            const subHint = document.createElement('span');
            subHint.className = 'text-muted fw-normal d-block small';
            subHint.textContent = 'Click or drag & drop to replace';
            statusEl.appendChild(subHint);

            if (!listEl) return;

            // For single file, use full width; for multiple, use grid layout
            if (!multiple && displayFiles.length === 1) {
                listEl.classList.add('file-preview-single');
            } else {
                listEl.classList.add('file-preview-grid');
            }

            const inputId = $input.attr('id') ? `#${$input.attr('id')}` : inputSelector;

            displayFiles.forEach((file, index) => {
                const isImage = file.type.startsWith('image/');
                const isPDF = file.type === 'application/pdf';

                const removeBtn = document.createElement('button');
                removeBtn.type = 'button';
                removeBtn.className = 'btn btn-remove-preview-file';
                removeBtn.dataset.fileIndex = String(index);
                removeBtn.dataset.inputTarget = inputId;
                removeBtn.title = 'Remove file';
                removeBtn.setAttribute('aria-label', `Remove ${file.name}`);
                const xIcon = document.createElement('i');
                xIcon.className = 'fa-solid fa-xmark';
                removeBtn.appendChild(xIcon);

                if (isImage) {
                    const objectUrl = URL.createObjectURL(file);
                    const li = document.createElement('li');
                    li.className = 'list-group-item file-preview-item p-0 border-0';
                    li.appendChild(removeBtn);

                    const container = document.createElement('div');
                    container.className = 'file-preview-container';

                    const img = document.createElement('img');
                    img.src = objectUrl;
                    img.alt = file.name;
                    img.title = file.name;
                    img.className = 'file-preview-image';

                    const nameDiv = document.createElement('div');
                    nameDiv.className = 'file-preview-name';
                    nameDiv.textContent = file.name;

                    container.appendChild(img);
                    container.appendChild(nameDiv);
                    li.appendChild(container);
                    listEl.appendChild(li);
                } else if (isPDF) {
                    const objectUrl = URL.createObjectURL(file);
                    const li = document.createElement('li');
                    li.className = 'list-group-item file-preview-item p-0 border-0';
                    li.appendChild(removeBtn);

                    const container = document.createElement('div');
                    container.className = 'file-preview-container';

                    const embed = document.createElement('embed');
                    embed.src = objectUrl;
                    embed.type = 'application/pdf';
                    embed.className = 'w-100 rounded';
                    embed.style.height = '350px';
                    embed.style.minHeight = '40vh';

                    const nameDiv = document.createElement('div');
                    nameDiv.className = 'file-preview-name text-center small p-1 text-truncate';
                    nameDiv.title = file.name;
                    nameDiv.textContent = file.name;

                    container.appendChild(embed);
                    container.appendChild(nameDiv);
                    li.appendChild(container);
                    listEl.appendChild(li);
                } else {
                    const li = document.createElement('li');
                    li.className = 'list-group-item file-preview-item p-3 border-0 d-flex flex-column align-items-center justify-content-center bg-light rounded';
                    li.appendChild(removeBtn);

                    const fileIcon = document.createElement('i');
                    fileIcon.className = 'bi bi-file-earmark fs-2 text-secondary mb-2';

                    const nameSpan = document.createElement('span');
                    nameSpan.className = 'file-preview-name text-center small';
                    nameSpan.title = file.name;
                    nameSpan.textContent = file.name;

                    li.appendChild(fileIcon);
                    li.appendChild(nameSpan);
                    listEl.appendChild(li);
                }
            });
        });
    }

    updateFileList('#deposit_slip_input', '#deposit_slip_list', true);
    updateFileList('#form_2307_input', '#form_2307_list', false);

    // Drag-and-drop & keyboard accessibility for Tax Submissions dropzones
    $(document).off('dragenter.tax_dropzone dragover.tax_dropzone', '#submitDocsModal .tax-file-dropzone')
               .on('dragenter.tax_dropzone dragover.tax_dropzone', '#submitDocsModal .tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        $(this).addClass('is-dragover');
    });

    $(document).off('dragleave.tax_dropzone dragend.tax_dropzone', '#submitDocsModal .tax-file-dropzone')
               .on('dragleave.tax_dropzone dragend.tax_dropzone', '#submitDocsModal .tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        const related = e.originalEvent && e.originalEvent.relatedTarget;
        if (!related || !this.contains(related)) {
            $(this).removeClass('is-dragover');
        }
    });

    $(document).off('drop.tax_dropzone', '#submitDocsModal .tax-file-dropzone')
               .on('drop.tax_dropzone', '#submitDocsModal .tax-file-dropzone', function (e) {
        e.preventDefault();
        e.stopPropagation();
        const $dropzone = $(this);
        $dropzone.removeClass('is-dragover');

        const droppedFiles = e.originalEvent && e.originalEvent.dataTransfer && e.originalEvent.dataTransfer.files;
        if (!droppedFiles || !droppedFiles.length) return;

        const targetSelector = $dropzone.data('target-input');
        const inputEl = targetSelector ? document.querySelector(targetSelector) : $dropzone.find('input[type="file"]')[0];
        if (!inputEl) return;

        const isMultiple = $(inputEl).data('multiple') === true || $(inputEl).data('multiple') === 'true';
        const dt = new DataTransfer();
        if (isMultiple) {
            Array.from(droppedFiles).forEach(file => dt.items.add(file));
        } else {
            dt.items.add(droppedFiles[0]);
        }
        inputEl.files = dt.files;
        $(inputEl).trigger('change');
    });

    $(document).off('keydown.tax_dropzone', '#submitDocsModal .tax-file-dropzone')
               .on('keydown.tax_dropzone', '#submitDocsModal .tax-file-dropzone', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            const targetSelector = $(this).data('target-input');
            const inputEl = targetSelector ? document.querySelector(targetSelector) : $(this).find('input[type="file"]')[0];
            if (inputEl) inputEl.click();
        }
    });

    $(document).off('click.tax_dropzone', '#submitDocsModal .btn-remove-preview-file')
               .on('click.tax_dropzone', '#submitDocsModal .btn-remove-preview-file', function (e) {
        e.preventDefault();
        e.stopPropagation();

        const indexToRemove = Number($(this).data('file-index'));
        const inputSelector = $(this).data('input-target');
        const inputEl = inputSelector ? document.querySelector(inputSelector) : null;
        if (!inputEl || !inputEl.files) return;

        const dt = new DataTransfer();
        Array.from(inputEl.files).forEach((file, idx) => {
            if (idx !== indexToRemove) {
                dt.items.add(file);
            }
        });
        inputEl.files = dt.files;
        $(inputEl).trigger('change');
    });


    const params = new URLSearchParams(window.location.search);
    const submissionId = params.get("open_submission");

    if (submissionId) {
        const modalElement = document.getElementById("submissionModal");
        if (modalElement) {
            const modal = new bootstrap.Modal(modalElement);
            modal.show();

            const fetchUrl = window.location.pathname.includes("/admin")
                ? "/admin/tax_submissions/" + submissionId
                : "/tax_submissions/" + submissionId;

            $.ajax({
                url: fetchUrl,
                dataType: "script",
                headers: { Accept: "text/javascript" }
            });
        }
    }

    $(document).off('hidden.bs.modal.submission', '#submissionModal').on('hidden.bs.modal.submission', '#submissionModal', function () {
        const url = new URL(window.location);
        if (url.searchParams.has('open_submission')) {
            url.searchParams.delete('open_submission');
            window.history.replaceState({}, document.title, url.pathname + (url.search ? url.search : '') + url.hash);
        }
    });

    // In-place reviewer quick action button processing without page refresh
    $(document).off('submit.reviewer_quick_action', '.reviewer-quick-action-form').on('submit.reviewer_quick_action', '.reviewer-quick-action-form', function (e) {
        e.preventDefault();
        const $form = $(this);
        const $btn = $form.find('button[type="submit"]');
        if ($btn.prop('disabled')) return false;

        $btn.prop('disabled', true);
        const originalHtml = $btn.html();
        $btn.html('<i class="fa-solid fa-spinner fa-spin"></i> <span>Updating...</span>');

        $.ajax({
            url: $form.attr('action'),
            type: 'PATCH',
            data: $form.serialize(),
            dataType: 'script',
            headers: {
                'Accept': 'text/javascript',
                'X-Requested-With': 'XMLHttpRequest'
            }
        }).fail(function () {
            $btn.prop('disabled', false).html(originalHtml);
            alert('Failed to update submission status. Please try again.');
        });
        return false;
    });

    // Track pending resubmission prefill so fetch_invoices selects it instead of overriding it
    let pendingPrefillCompanyId = $("#prefill_company_id").val() || null;
    let pendingPrefillInvoiceId = $("#prefill_invoice_id").val() || null;

    // Fetch invoices based on selected company and auto-select the most recent invoice
    $(document).off("change", "#company_select").on("change", "#company_select", function () {
        const companyId = $(this).val();
        const invoiceSelectEl = document.getElementById("invoice_select");
        const $invoiceSelect = $(invoiceSelectEl);

        if (!invoiceSelectEl) return;

        // Clear and show loading state
        const loadingOpt = document.createElement("option");
        loadingOpt.value = "";
        loadingOpt.textContent = "Loading invoices...";
        invoiceSelectEl.replaceChildren(loadingOpt);
        $invoiceSelect.prop('disabled', true);

        if (companyId) {
            $.ajax({
                url: "/tax_submissions/fetch_invoices",
                data: { company_id: companyId },
                dataType: "json",
                success: function (data) {
                    const defaultOpt = document.createElement("option");
                    defaultOpt.value = "";
                    defaultOpt.textContent = "Select Invoice";
                    invoiceSelectEl.replaceChildren(defaultOpt);

                    if (!Array.isArray(data) || data.length === 0) {
                        const emptyOpt = document.createElement("option");
                        emptyOpt.value = "";
                        emptyOpt.disabled = true;
                        emptyOpt.textContent = "No invoices available for this company";
                        invoiceSelectEl.appendChild(emptyOpt);
                    } else {
                        data.forEach(function (invoice) {
                            const opt = document.createElement("option");
                            opt.value = String(invoice.id);
                            opt.textContent = invoice.display_name || invoice.invoice_number || String(invoice.id);
                            invoiceSelectEl.appendChild(opt);
                        });

                        // Preserve resubmission prefill if applicable; otherwise auto-select the most recent invoice
                        const hasMatchingPrefill = pendingPrefillInvoiceId &&
                            String(pendingPrefillCompanyId) === String(companyId) &&
                            data.some(inv => String(inv.id) === String(pendingPrefillInvoiceId));

                        if (hasMatchingPrefill) {
                            $invoiceSelect.val(String(pendingPrefillInvoiceId));
                            pendingPrefillInvoiceId = null;
                            pendingPrefillCompanyId = null;
                        } else {
                            $invoiceSelect.val(String(data[0].id));
                        }
                    }
                    $invoiceSelect.prop('disabled', false);
                },
                error: function (xhr, status, error) {
                    console.error("Error fetching invoices:", error);
                    const errOpt = document.createElement("option");
                    errOpt.value = "";
                    errOpt.disabled = true;
                    errOpt.textContent = "Error loading invoices. Please try again.";
                    invoiceSelectEl.replaceChildren(errOpt);
                    $invoiceSelect.prop('disabled', false);

                    if (window.showFlashMessage) {
                        window.showFlashMessage("Unable to load invoices. Please refresh the page and try again.", "danger");
                    }
                }
            });
        } else {
            const defaultOpt = document.createElement("option");
            defaultOpt.value = "";
            defaultOpt.textContent = "Select Invoice";
            invoiceSelectEl.replaceChildren(defaultOpt);
            $invoiceSelect.prop('disabled', false);
        }
    });

    // Reopen modal if there are errors
    if ($("#has_submission_errors").val() === "true") {
        const modalEl = document.getElementById("submitDocsModal");
        if (modalEl) {
            const submitModal = (typeof bootstrap !== 'undefined' && bootstrap.Modal) ? bootstrap.Modal.getOrCreateInstance(modalEl) : new bootstrap.Modal(modalEl);
            submitModal.show();
        }
    }

    // Automatically open submit tax documents modal if requested via URL query param or anchor
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get("open_modal") === "true" || $("#open_submit_modal").val() === "true" || window.location.hash === "#submitDocsModal" || window.location.hash === "#submit-tax-documents") {
        const modalEl = document.getElementById("submitDocsModal");
        if (modalEl) {
            setTimeout(function () {
                const submitModal = (typeof bootstrap !== 'undefined' && bootstrap.Modal) ? bootstrap.Modal.getOrCreateInstance(modalEl) : new bootstrap.Modal(modalEl);
                submitModal.show();
            }, 100);
        }
    }

    // Handle resubmission flow: pre-fill company and invoice, then open modal
    const prefillCompanyId = $("#prefill_company_id").val();
    const prefillInvoiceId = $("#prefill_invoice_id").val();

    if (prefillCompanyId && prefillInvoiceId) {
        // Set the company select value
        $("#company_select").val(prefillCompanyId).trigger("change");

        // Wait for invoices to load, then set the invoice value
        setTimeout(function () {
            $("#invoice_select").val(prefillInvoiceId);

            // Open the modal
            const modalEl = document.getElementById("submitDocsModal");
            if (modalEl) {
                const submitModal = new bootstrap.Modal(modalEl);
                submitModal.show();
            }
        }, 500);
    }

    // Keep redirect_url in sync with current table page, tab, and filters
    syncTaxSubmissionRedirectUrl();
    const submitModalEl = document.getElementById('submitDocsModal');
    if (submitModalEl) {
        $(submitModalEl).off('show.bs.modal.redirectSync').on('show.bs.modal.redirectSync', syncTaxSubmissionRedirectUrl);
    }

    // Form validation before submission
    $(document).off("submit", "#submitDocsModal form").on("submit", "#submitDocsModal form", function (e) {
        syncTaxSubmissionRedirectUrl();
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

    // Global Header Export CSV Button Handler
    $(document).off('click', '#exportTaxSubmissionsBtn').on('click', '#exportTaxSubmissionsBtn', function (e) {
        e.preventDefault();
        const $activePane = $('.tab-content > .tab-pane.active, .tab-content > .tab-pane.show.active, .tab-content .tab-pane.active').first();
        const $activeTable = $activePane.find('.submissionsTable:visible, .submissionsTable').first();
        if ($activeTable.length && $.fn.DataTable.isDataTable($activeTable[0])) {
            const api = $activeTable.DataTable();
            const isArchived = $activePane.attr('id') === 'archived';
            exportSubmissionsToCsv(api, isArchived ? 'tax_submissions_archived' : 'tax_submissions_active', false);
        }
    });
}

// Listen for theme changes and update modal file inputs
document.addEventListener('theme:changed', function (e) {
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

document.addEventListener("turbo:before-cache", function () {
    $('.submissionsTable').each(function () {
        if ($.fn.DataTable.isDataTable(this)) {
            $(this).DataTable().destroy();
        }
    });
});

document.addEventListener("turbo:load", initClientSubmissionsPage);
document.addEventListener("DOMContentLoaded", initClientSubmissionsPage);
window.addEventListener("popstate", function () {
    if (window.location.pathname.includes("/tax_submissions") && $('.submissionsTable').length > 0) {
        initClientSubmissionsPage();
    }
});

// Init immediately to catch late-loading scripts
initClientSubmissionsPage();
