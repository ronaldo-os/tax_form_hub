if (window.location.pathname.includes("/invoices")) {
    $(document).ready(function() {
        $('#invoice-table').DataTable();
    });


    $(document).ready(function () {

        //----------------------------------------------------- INVOICE NUMBER SECTION: Add optional Field
        
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
            "billingReferenceId": [
                { name: "billingReferenceId.reference_id", label: "Billing reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "contractDocumentReferenceId": [
                { name: "contractDocumentReferenceId.contract_number", label: "Contract number", type: "text", cols: 12, class: "mb-3" },
            ],
            "despatchDocumentReference.id": [
                { name: "despatchDocumentReference.id.shipping_reference", label: "Shipping Notice Reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "despatchDocumentReference.issueDate": [
                { name: "despatchDocumentReference.issueDate.issue_date", label: "Shipping Notice Issue Date", type: "date", cols: 12, class: "mb-3" },
            ],
            "receiptDocumentReference.id": [
                { name: "receiptDocumentReference.id.receipt_reference", label: "Goods Receipt Reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "receiptDocumentReference.issueDate": [
                { name: "receiptDocumentReference.issueDate.receipt_reference_date", label: "Goods Receipt Issue Date", type: "date", cols: 12, class: "mb-3" },
            ],
            "accountingCost": [
                { name: "accountingCost.cost_center", label: "Cost center", type: "text", cols: 12, class: "mb-3" },
            ],
            "customerPartyContactName": [
                { name: "customerPartyContactName.person_reference", label: "Person reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[BOL ID]": [
                { name: "additionalReferences[BOL ID].transport_reference", label: "Transport Reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "BOLIssueDate": [
                { name: "BOLIssueDate.transport_reference_date", label: "Transport Reference Issue Date", type: "date", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[File ID]": [
                { name: "additionalReferences[File ID].file_id", label: "File Id", type: "text", cols: 12, class: "mb-3" },
            ],
            "customerAssignedId": [
                { name: "customerAssignedId.customer_id", label: "Customer account ID", type: "text", cols: 12, class: "mb-3" },
            ],
            "taxPointDate": [
                { name: "taxPointDate.tax_point_date", label: "Tax point date", type: "date", cols: 12, class: "mb-3" },
            ],
            "supplierCommissionNumber": [
                { name: "supplierCommissionNumber.number_of_seller", label: "Commission number of seller", type: "text", cols: 12, class: "mb-3" },
            ],
            "supplierPhysicalLocationValue": [
                { name: "supplierPhysicalLocationValue.data_universal_numbering_system", label: "Data universal numbering system", type: "text", cols: 12, class: "mb-3" },
            ],
            "deliveryTerms": [
                { name: "deliveryTerms.delivery_terms", label: "Delivery Terms", type: "text", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[Interim Hours]": [
                { name: "additionalReferences[Interim Hours].interim_hours", label: "Interim Hours", type: "text", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[BookingNumber]": [
                { name: "additionalReferences[BookingNumber].booking_number", label: "Booking Number", type: "text", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[PaymentReference]": [
                { name: "additionalReferences[PaymentReference].payment_reference", label: "Payment Reference", type: "text", cols: 12, class: "mb-3" },
            ],
            "promisedDeliveryPeriod": [
                { name: "promisedDeliveryPeriod.delivery_period", label: "Delivery period", type: "text", cols: 12, class: "mb-3" },
            ],
            "additionalReferences[Clearance Clave]": [
                { name: "additionalReferences[Clearance Clave].clearance_clave", label: "Clearance Clave", type: "text", cols: 12, class: "mb-3" },
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

            let rowsHtml = `
            <div class="mb-3 position-relative border rounded p-3 pt-3" data-optional-group="${key}">
                <button type="button" class="btn btn-sm btn-outline-danger rounded position-absolute top-0 end-0 m-2 remove-group">×</button>
            `;

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

            rowsHtml += `</div>`;
            }

            $('#optional_fields_container').append(rowsHtml);
            $(this).val('');
        });

        $(document).on('click', '.remove-group', function () {
            $(this).closest('[data-optional-group]').remove();
        });
    });


    //----------------------------------------------------- PAYMENT TERMS FIELD 

    const payment_terms_fieldTypeMap = {
        paymentterms: [
            { name: "paymentterms.discount_percent", label: "Discount Percent", type: "text", cols: 6},
            { name: "paymentterms.surcharge_percent", label: "Surcharge Percent", type: "text", cols: 6},
            { name: "paymentterms.settelement_start_date", label: "Settlement Start Date", type: "date", cols: 6},
            { name: "paymentterms.penalty_start_date", label: "Penalty Start Date", type: "date", cols: 6},
            { name: "paymentterms.settlement_end_date", label: "Settlement End Date", type: "date", cols: 6},
            { name: "paymentterms.penalty_end_date", label: "Penalty End Date", type: "date", cols: 6},
            { name: "paymentterms.note", label: "Note", type: "textarea", cols: 12 },
        ],
        cash: [
            { name: "cash.cash", label: "Cash Payment", type: "text_only", cols: 12 }
        ],
        check: [
            { name: "check.check", label: "Check Payment", type: "text_only", cols: 12 },
        ],
        bank: [
            { name: "bank.name", label: "Bank name", type: "text", cols: 12 },
            { name: "bank.sortcode", label: "Sort Code", type: "text", cols: 6 },
            { name: "bank.account_number", label: "Account number", type: "text", cols: 6 },
            { name: "bank.account_holder_name", label: "Account holder name (optional) ", type: "text", cols: 12 },
            { name: "bank.street_name", label: "Street name (optional)", type: "text", cols: 12 },
            { name: "bank.additional_street_name", label: "Additional street name (optional)", type: "text", cols: 12 },
            { name: "bank.building_number", label: "Building number (optional)", type: "text", cols: 6 },
            { name: "bank.city", label: "City (optional)", type: "text", cols: 6 },
            { name: "bank.zip_code", label: "Postal/Zip code (optional)", type: "text", cols: 12 },
            { name: "bank.state", label: "State/Region (optional)", type: "text", cols: 12 },
            { name: "bank.address_line", label: "Address line (optional)", type: "text", cols: 12 },
            { name: "bank.country", label: "Country (optional)", type: "text", cols: 12 },
            { name: "bank.note", label: "Payment note", type: "text", cols: 12 },
        ],
        bank_card: [
            { name: "bank_card.bank_card", label: "Bank Card", type: "text_only", cols: 6 },
        ],
        debit: [
            { name: "debit.name", label: "Bank name", type: "text", cols: 12 },
            { name: "debit.sortcode", label: "Sort Code", type: "text", cols: 6 },
            { name: "debit.account_number", label: "Account number", type: "text", cols: 6 },
            { name: "debit.account_holder_name", label: "Account holder name (optional) ", type: "text", cols: 12 },
            { name: "debit.street_name", label: "Street name (optional)", type: "text", cols: 12 },
            { name: "debit.additional_street_name", label: "Additional street name (optional)", type: "text", cols: 12 },
            { name: "debit.building_number", label: "Building number (optional)", type: "text", cols: 6 },
            { name: "debit.city", label: "City (optional)", type: "text", cols: 6 },
            { name: "debit.zip_code", label: "Postal/Zip code (optional)", type: "text", cols: 12 },
            { name: "debit.state", label: "State/Region (optional)", type: "text", cols: 12 },
            { name: "debit.address_line", label: "Address line (optional)", type: "text", cols: 12 },
            { name: "debit.country", label: "Country (optional)", type: "text", cols: 12 },
            { name: "debit.note", label: "Payment note", type: "text", cols: 12 },
        ],
        bic_iban: [
            { name: "bic_iban.bic_swift", label: "BIC/SWIFT", type: "text", cols: 4 },
            { name: "bic_iban.iban", label: "IBAN", type: "text", cols: 8 },
            { name: "bic_iban.note", label: "Payment note", type: "text", cols: 12 },
        ],
    };

    $('#payment_terms_select').on('change', function () {
        const key = $(this).val();
        const key_text = $(this).find('option:selected').text().trim();
        if (!key) return;

        if ($(`#payment_terms_parent_div [data-optional-group="${key}"]`).length > 0) {
        alert("This payment term group is already added.");
        $(this).val('');
        return;
        }

        const fields = payment_terms_fieldTypeMap[key];
        if (!fields || !Array.isArray(fields)) return;

        let groupHtml = `
        <div class="mb-3 border rounded p-3 pt-3" data-optional-group="${key}">
            <div class="d-flex justify-content-between align-items-center mb-3">
                <h5 class="mb-0">${key_text}</h5>
                <button type="button" class="btn btn-sm btn-outline-danger remove-group">×</button>
            </div>
        `;

        for (let i = 0; i < fields.length; i += 12) {
        groupHtml += `<div class="row">`;

        const subFields = fields.slice(i, i + 12);
        subFields.forEach(field => {
        const colClass = `col-md-${field.cols || 6} ${field.class || ""}`;
        let inputHtml = "";

        if (field.type === "text_only") {
            inputHtml = `<p class="mb-0">${field.label}</p>`;
        } else {
            if (field.type === "select") {
            inputHtml = `<select name="optional_fields[${field.name}]" class="form-select">
                ${field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('')}
            </select>`;
            } else if (field.type === "textarea") {
            inputHtml = `<textarea name="optional_fields[${field.name}]" class="form-control"></textarea>`;
            } else {
            inputHtml = `<input type="${field.type}" name="optional_fields[${field.name}]" class="form-control">`;
            }

            groupHtml += `
            <div class="${colClass} mb-3">
                <label class="form-label">${field.label}</label>
                ${inputHtml}
            </div>
            `;
        }
        });


        groupHtml += `</div>`; 
        }

        groupHtml += `</div>`; 
        $('#payment_terms_parent_div').append(groupHtml);
        $(this).val('');
    });

    $(document).on('click', '.remove-group', function () {
        $(this).closest('[data-optional-group]').remove();
    });

    //----------------------------------------------------- DELIVERY DETAILS BUTTON TOGGLE

    const $delivery_details_button = $('[data-bs-toggle="collapse"][data-bs-target="#delivery_details_parent_div"]');
    const delivery_details_target_id = $delivery_details_button.attr('data-bs-target');
    const $delivery_details_target = $(delivery_details_target_id);

    $delivery_details_target.on('show.bs.collapse', function () {
      $delivery_details_button.text('− Hide Delivery Details');
    });

    $delivery_details_target.on('hide.bs.collapse', function () {
      $delivery_details_button.text('+ Delivery Details');
    });


}
