if (window.location.pathname.includes("/invoices")) {
    $(document).ready(function() {
        $('#invoice-table').DataTable();
    });


    $(document).ready(function () {
        const fieldTypeMap = {
            "customsDeclarations": [
                { name: "customsDeclarations.number_1", label: "Reference Number of Customs Form No.1,9", type: "text", cols: 12, class: "mb-3" },
                { name: "customsDeclarations.number_2", label: "Reference Number of Customs Form No.2", type: "text", cols: 12, class: "mb-3" },
            ],
            "taxExchangeRateFields": [
                { name: "taxExchangeRateFields.rate", label: "Exchange rate", type: "text", cols: 6, class: "mb-3" },
                { name: "taxExchangeRateFields.currency", label: "Currency", type: "select", cols: 6, options: ["PHP", "USD"], class: "mb-3" },
                { name: "taxExchangeRateFields.date_of_rate", label: "Date of exchange rate", type: "date", cols: 6, class: "mb-3" },
                { name: "taxExchangeRateFields.converted_tax_total", label: "Converted tax total", type: "text", cols: 6, class: "mb-3" },
                { name: "taxExchangeRateFields.converted_doc_total_incl", label: "Converted Document Total (incl taxes)", type: "text", cols: 12, class: "mb-3" },
                { name: "taxExchangeRateFields.converted_doc_total_excl", label: "Converted Document Total (excl taxes)", type: "text", cols: 12, class: "mb-3" },
            ],
            "transactionVatType": [
                { name: "transactionVatType.vat_type", label: "Transaction VAT Type", type: "select", cols: 12, options: ["Collection", "Debit"], class: "mb-3" },
            ],
            "orderReferenceId": [
                { name: "orderReferenceId.order_number", label: "Purchase order number", type: "text", cols: 12, class: "mb-3" },
            ],
            "orderReferenceIssueDate": [
                { name: "orderReferenceIssueDate.issue_date", label: "Purchase order number", type: "date", cols: 12, class: "mb-3" },
            ],
            "billingReferenceId": [
                { name: "billingReferenceId.reference_id", label: "Billing reference", type: "text", cols: 12, class: "mb-3" },
            ],
        };

        $('#optionalField').on('change', function () {
            const key = $(this).val();
            if (!key) return;

            if ($(`[data-optional-group="${key}"]`).length > 0) {
            alert("This group is already added.");
            $(this).val('');
            return;
            }

            const fields = fieldTypeMap[key];
            if (!fields || !Array.isArray(fields)) return;

            let rowsHtml = `<div class="mb-3" data-optional-group="${key}"><hr>`;

            // Render fields in Bootstrap rows
            for (let i = 0; i < fields.length; i += 12) {
            rowsHtml += `<div class="row">`;

            const subFields = fields.slice(i, i + 12);
            subFields.forEach(field => {
                const fieldClass = field.class || "";
                const colClass = `col-md-${field.cols || 6} ${fieldClass}`;
                let inputHtml = "";

                if (field.type === "select") {
                inputHtml = `<select name="optional_fields[${field.name}]" class="form-select">
                    ${field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('')}
                </select>`;
                } else if (field.type === "textarea") {
                inputHtml = `<textarea name="optional_fields[${field.name}]" class="form-control"></textarea>`;
                } else {
                inputHtml = `<input type="${field.type}" name="optional_fields[${field.name}]" class="form-control">`;
                }

                rowsHtml += `
                <div class="${colClass}">
                    <label class="form-label">${field.label}</label>
                    ${inputHtml}
                </div>
                `;
            });

            rowsHtml += `</div>`; // close row
            }

            rowsHtml += `
                <div class="row mt-2">
                    <div class="col-12 text-end">
                    <button type="button" class="btn btn-outline-danger remove-group">× Remove</button>
                    </div>
                </div>
            </div>`;

            $('#optional_fields_container').append(rowsHtml);
            $(this).val('');
        });

        // Remove entire group
        $(document).on('click', '.remove-group', function () {
            $(this).closest('[data-optional-group]').remove();
        });
    });


}
