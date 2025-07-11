import { COUNTRY_OPTIONS, DISCOUNT_OPTIONS } from "./long_select_options/options";

if (window.location.pathname.includes("/invoices")) {

    $(document).ready(function () {

        $('#invoice-table').DataTable();
        recalculateTotals();

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

    // ----------------------------------------------------- DELIVERY DETAILS BUTTON TOGGLE

    var $btn = $('[data-bs-toggle="collapse"][data-bs-target="#delivery_details_parent_div"]');
    var $target = $($btn.data('bs-target'));

    $target.on('show.bs.collapse hide.bs.collapse', function (e) {
    var symbol = e.type === 'show' ? '−' : '+';
    $btn.text(symbol + ' Delivery Details');
    });
    
    //----------------------------------------------------- PAYMENT TERMS LOCATIONS BUTTON TOGGLE

    $(document).on('click', '.location-toggle-btn', function () {
        const $btn = $(this);
        const type = $btn.data('type');
        const wrapperId = `#${type.toLowerCase().replace(/ /g, '_')}_selector_wrapper`;
        const $wrapper = $(wrapperId);

        $wrapper.slideToggle(200, function () {
            const isVisible = $wrapper.is(':visible');
            $btn.html(`${isVisible ? '–' : '+'} ${type} Details`);
        });
    });

    $('.toggle-location-details').on('click', function (e) {
      e.preventDefault();
      const type = $(this).data('type').toLowerCase().replace(/\s+/g, '_');
      $(`#${type}_selector_wrapper`).toggle();
    });

    $('.clear-location-details').on('click', function (e) {
      e.preventDefault();
      const type = $(this).data('type').toLowerCase().replace(/\s+/g, '_');
      $(`#${type}_select`).val('');
      $(`#${type}_details`).hide();
    });

    $('.location-select').on('change', function () {
        const type = $(this).data('type').toLowerCase().replace(/\s+/g, '_');
        const selectedId = $(this).val();

        if (!selectedId) {
            $(`#${type}_details`).hide();
            return;
        }

        $.ajax({
            url: `/locations/${selectedId}.json`,
            method: 'GET',
            success: function (data) {
            const details = $(`#${type}_details`);
            details.find('.location_name').text(data.location_name || '');
            details.find('.company_name').text(data.company_name || '');
            details.find('.tax_number').text(data.tax_number ? `Tax number : ${data.tax_number}` : '');
            details.find('.street').text(data.street || '');
            details.find('.city').text(data.city || '');
            details.find('.country').text(data.country || '');
            details.show();
            },
            error: function () {
            alert('Failed to fetch location details.');
            $(`#${type}_details`).hide();
            }
        });
    });

    //----------------------------------------------------- ADD FOOTER BUTTON TOGGLE

    $('.add-footer-toggle-btn').on('click', function() {
      const $button = $(this);
      const $target = $('#footer_wrapper_parent_div');

      $target.slideToggle(300, function() {
        const isVisible = $target.is(':visible');
        $button.text(isVisible ? '− Remove footer notes' : '+ Add footer notes');
      });
    });


    $(document).ready(function () {

    const $select = $('#initial_delivery_details_country');

    if ($select.length) {
      $.each(COUNTRY_OPTIONS, function (i, country) {
        $select.append($('<option>', {
          value: country,
          text: country
        }));
      });
    }

    let lineIndex = 1;

    // Utility Functions
    function updateRemoveButtons() {
      const isSingleRow = $('#line-items .line-item, #line-items .discount-item').length <= 1;
      $('#line-items .remove-line').toggle(!isSingleRow);
    }

    function getDropdownOptions() {
      const options = [
        'discount', 'charge', 'bolid', 'fileid', 'taxexemptionreason',
        'modelname', 'hsnsac', 'documentreference', 'documentlinereference',
        'accountingcost', 'deliveryaddress', 'actualdeliverydate', 'buyersitemidentification',
        'origincountry', 'eccn', 'eangtin', 'incoterms', 'manufacturename',
        'trackingid', 'serialID', 'linenote', 'despatchlinedocumentreference',
        'despatchlineiddocumentreference', 'receiptlinedocumentreference', 'receiptlineiddocumentreference'
      ];

      return options.map(opt => `<option value="${opt}">${opt.replace(/([a-z])([A-Z])/g, '$1 $2')}</option>`).join('');
    }

    function getLineItemHTML(index) {
      return `
        <tr class="line-item" data-line-index="${index}">
          <td><button type="button" class="btn btn-sm btn-outline-primary toggle-dropdown">+</button></td>
          <td><input type="text" class="form-control item-id"></td>
          <td><input type="text" class="form-control description"></td>
          <td><input type="number" class="form-control quantity" value="1"></td>
          <td><input type="text" class="form-control unit" value="pcs"></td>
          <td><input type="number" class="form-control price" step="0.01"></td>
          <td><input type="number" class="form-control tax" step="0.01"></td>
          <td class="text-end total">0.00</td>
          <td><button type="button" class="btn btn-sm btn-outline-danger remove-line">&minus;</button></td>
        </tr>
        <tr class="dropdown_per_line hidden">
          <td colspan="3">
            <select name="additional_field_${index}" id="additional_field_${index}" class="no-label form-select">
              <option value="">Add optional field</option>
              ${getDropdownOptions()}
            </select>
          </td>
          <td colspan="6"></td>
        </tr>
      `;
    }

    
    // Event Listeners
    $('#add-line').on('click', function () {
      $('#line-items').append(getLineItemHTML(lineIndex++));
      updateRemoveButtons();
    });

    $(document).on('click', '.toggle-dropdown', function () {
      const $btn = $(this);
      const $currentLineItem = $btn.closest('tr');
      let $next = $currentLineItem.next();
      const $toggleRows = [];

      while ($next.length && !$next.hasClass('line-item')) {
        if ($next.hasClass('optional-field-row') || $next.hasClass('dropdown_per_line')) {
          $toggleRows.push($next);
        }
        $next = $next.next();
      }

      const shouldShow = $toggleRows.length > 0 && !$toggleRows[0].is(':visible');
      $toggleRows.forEach($row => $row.toggle(shouldShow));
      $btn.text(shouldShow ? '−' : '+');
    });




    
    // Initialization   
    updateRemoveButtons();

   const discount_fieldTypeMap = {
    discount: [
      { name: "discount.discount_type", label: "Discount type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
      { name: "discount.discount_type_edit", label: "Edit type (if needed)", type: "text", cols: 4 },
      { name: "discount.qty", label: "Quantity", type: "text", cols: 2 },
      { name: "discount.unit", label: "Unit", type: "select", options: ["PHP", "%"], cols: 2 },
      { name: "discount.total", label: "Total", type: "text_only", cols: 2 },

    ],
    charge: [
      { name: "charge.charge_type", label: "Charge type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
      { name: "charge.charge_type_edit", label: "Edit type (if needed)", type: "text", cols: 4 },
      { name: "charge.qty", label: "Quantity", type: "text", cols: 2 },
      { name: "charge.unit", label: "Unit", type: "select", options: ["PHP", "%"], cols: 2 },
      { name: "charge.total", label: "Total", type: "text_only", cols: 2 },
    ],
    bolid: [
      { name: "bolid.transport_reference", label: "Transport Reference", type: "text", cols: 4 }
    ],
    fileid: [
      { name: "fileid.file_id", label: "File ID", type: "text", cols: 4 }
    ],
    taxexemptionreason: [
      { name: "taxexemptionreason.tax_exemption_reason", label: "Tax exemption reason", type: "text", cols: 4 }
    ],
    modelname: [
      { name: "modelname.model_name", label: "Model name", type: "text", cols: 4 }
    ],
    hsnsac: [
      { name: "hsnsac.hsn_sac", label: "HSN/SAC", type: "select" , options: ["HSN", "SAC"], cols: 4 },
      { name: "hsnsac.qty", label: "Quantity", type: "text", cols: 4 },
    ],
    documentreference: [
      { name: "documentreference.purchase_order_number", label: "Purchase order number", type: "text", cols: 4 }
    ],
    documentlinereference: [
      { name: "documentlinereference.purchase_order_line_number", label: "Purchase order line number", type: "text", cols: 4 }
    ],
    accountingcost: [
      { name: "accountingcost.cost_center", label: "Cost center", type: "text", cols: 4 }
    ],
    deliveryaddress: [
      {
        name: "deliveryaddress.country_origin",
        label: "Country/Region",
        type: "select",
        options: COUNTRY_OPTIONS,
        cols: 4
      },
      { name: "deliveryaddress.postbox", label: "Postbox", type: "text", cols: 4 },
      { name: "deliveryaddress.street", label: "Street", type: "text", cols: 4 },
      { name: "deliveryaddress.number", label: "Number", type: "text", cols: 4 },
      { name: "deliveryaddress.locality_name", label: "Locality name", type: "text", cols: 4 },
      { name: "deliveryaddress.postal_zipcode", label: "Postal/ZIP", type: "text", cols: 4 },
      { name: "deliveryaddress.city", label: "City", type: "text", cols: 4 },
      { name: "deliveryaddress.location_id", label: "Location Id", type: "text", cols: 4 },
    ],
    actualdeliverydate: [
      { name: "actualdeliverydate.delivery_date", label: "Delivery Date", type: "date", cols: 4 }
    ],
    buyersitemidentification: [
      { name: "buyersitemidentification.buyer_material_number", label: "Buyer material number", type: "text", cols: 4 }
    ],
    origincountry: [
      {
        name: "origincountry.country_origin",
        label: "Country of origin",
        type: "select",
        options: COUNTRY_OPTIONS,
        cols: 4
      }
    ],
    eccn: [
      { name: "eccn.commodity_classification", label: "Commodity classification: ECCN", type: "text", cols: 4 }
    ],
    eangtin: [
      { name: "eangtin.ean_gtin", label: "EAN/GTIN", type: "text", cols: 4 }
    ],
    incoterms: [
      { name: "incoterms.delivery_terms", label: "Delivery Terms", type: "text", cols: 4 }
    ],
    manufacturename: [
      { name: "manufacturename.manufacture_name", label: "Manufacture name", type: "text", cols: 4 }
    ],
    trackingid: [
      { name: "trackingid.freight_order_number", label: "Freight order number", type: "text", cols: 4 }
    ],
    serialID: [
      { name: "serialID.serial_id", label: "Serial number", type: "text", cols: 4 }
    ],
    linenote: [
      { name: "linenote.note", label: "Notes", type: "text", cols: 4 }
    ],
    despatchlinedocumentreference: [
      { name: "despatchlinedocumentreference.shipping_notice_reference", label: "Shipping Notice Reference", type: "text", cols: 4 }
    ],
    despatchlineiddocumentreference: [
      { name: "despatchlineiddocumentreference.shipping_notice_line_reference", label: "Shipping Notice Line Reference", type: "text", cols: 4 }
    ],
    receiptlinedocumentreference: [
      { name: "receiptlinedocumentreference.receipt_reference", label: "Goods Receipt Reference", type: "text", cols: 4 }
    ],
    receiptlineiddocumentreference: [
      { name: "receiptlineiddocumentreference.receipt_line_reference", label: "Goods Receipt Line Reference", type: "text", cols: 4 }
    ],
  };

  $(document).on('change', 'select[name^="optional_fields"]', function () {
    const $select = $(this);
    const selectedValue = $select.val();
    const $rowGroup = $select.closest('tr.optional-field-row');

    if ($select.attr('name').includes('discount.discount_type')) {
      const $editInput = $rowGroup.find('input[name^="optional_fields"][name*="discount.discount_type_edit"]');
      if ($editInput.length > 0) {
        $editInput.val(selectedValue);
      }
    }

    if ($select.attr('name').includes('charge.charge_type')) {
      const $editInput = $rowGroup.find('input[name^="optional_fields"][name*="charge.charge_type_edit"]');
      if ($editInput.length > 0) {
        $editInput.val(selectedValue);
      }
    }
  });


  $(document).on('change', 'select[id^="additional_field_"]', function () {
    const $select = $(this);
    const selectedKey = $select.val();
    const selectedText = $select.find("option:selected").text();
    if (!selectedKey) return;

    const $dropdownRow = $select.closest('tr.dropdown_per_line');
    const $lineItemRow = $dropdownRow.prev('.line-item');
    const rowIndex = $lineItemRow.data('line-index');

    const fields = discount_fieldTypeMap[selectedKey];
    if (!Array.isArray(fields)) return;

    let newRowHtml = `
        <tr class="optional-field-row" data-optional-group="${selectedKey}" data-line-index="${rowIndex}">
        <td colspan="9">
            <div class="p-2 border rounded bg-light mb-2">
            <p class="fs-5 mb-3 d-flex justify-content-between align-items-center">
                ${selectedText.toUpperCase()}
                <button type="button" class="btn btn-sm btn-outline-danger remove-group ms-2">×</button>
            </p>
            <div class="row g-3">`;

    fields.forEach(field => {
        const colClass = `col-md-${field.cols || 6} ${field.class || ''}`.trim();
        let inputHtml = '';

        if (field.type === "select") {
            const optionsHtml = field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('');
            inputHtml = `<select name="optional_fields[${rowIndex}][${field.name}]" class="form-select"${field.disabled ? ' disabled' : ''}>${optionsHtml}</select>`;
        } else if (field.type === "textarea") {
            inputHtml = `<textarea name="optional_fields[${rowIndex}][${field.name}]" class="form-control"${field.disabled ? ' disabled' : ''}></textarea>`;
        } else if (field.type === "text_only") {
            // Render a span for displaying the computed total
            inputHtml = `<span class="form-control-plaintext optional-total" data-total-type="${selectedKey}" data-line-index="${rowIndex}">0.00</span>`;
        } else {
            inputHtml = `<input type="${field.type}" name="optional_fields[${rowIndex}][${field.name}]" class="form-control"${field.disabled ? ' disabled' : ''}>`;
        }

        newRowHtml += `
        <div class="${colClass}">
            <div class="d-flex flex-column">
            <label class="form-label text-start w-100">${field.label}</label>
            ${inputHtml}
            </div>
        </div>`;
    });
    newRowHtml += `
            </div>
            </div>
        </td>
        </tr>`;

    $dropdownRow.before(newRowHtml);
    $select.val('');
  });


  // Remove dynamically added group
  $(document).on('click', '.remove-group', function () {
    $(this).closest('tr.optional-field-row').remove();
  });


  // Add header button 
  $('#add-discount-row').on('click', function () {
      const newRow = `
        <tr class="discount-item">
          <td class="align-top"></td>
          <td class="align-top">
            <select name="price_adjustment_discount" class="form-select">
              <option value="true">Discount</option>
              <option value="false">Charge</option>
              <option value="fixedtax">Fixed Tax</option>
            </select>
          </td>
          <td class="align-top">
            <input type="text" class="form-control description mb-2">
            <select name="price_adjustment_discount_type" class="form-select">
              <option value="Choose reason code" disabled selected>Choose reason code</option>
              <option value="Bank Charges">Bank Charges</option>
              <option value="Customs Duties">Customs Duties</option>
              <option value="Repair Costs">Repair Costs</option>
              <option value="Attorney Fees">Attorney Fees</option>
              <option value="Taxes">Taxes</option>
              <option value="Late Delivery">Late Delivery</option>
              <option value="Freight Costs">Freight Costs</option>
              <option value="Reason Unknown">Reason Unknown</option>
              <option value="Price Change">Price Change</option>
              <option value="Early payment allowance adjustment">Early payment allowance adjustment</option>
              <option value="Quantity Discount">Quantity Discount</option>
              <option value="Pricing Discount">Pricing Discount</option>
              <option value="Volume Discount">Volume Discount</option>
              <option value="Agreed Discount">Agreed Discount</option>
              <option value="Expediting fee">Expediting fee</option>
              <option value="Currency exchange differences">Currency exchange differences</option>
            </select>
          </td>
          <td class="align-top">
            <input type="number" class="form-control quantity" value="1">
          </td>
          <td class="align-top">
            <select name="price_adjustment_unit_type" class="form-select">
              <option value="true">%</option>
              <option value="false">PHP</option>
            </select>
          </td>
          <td class="align-top"></td>
          <td class="align-top"></td>
          <td class="align-top text-end total">0.00</td>
          <td class="align-top">
            <button type="button" class="btn btn-sm btn-outline-danger remove-line">−</button>
          </td>
        </tr>
      `;

      $('#line-items').append(newRow);
      updateRemoveButtons(); 
    });

    $('#line-items').on('click', '.remove-line', function () {
      const $lineItem = $(this).closest('tr');

      let $next = $lineItem.next();
      const $relatedRows = [];

      while ($next.length && !$next.hasClass('line-item')) {
        if ($next.hasClass('dropdown_per_line') || $next.hasClass('optional-field-row')) {
          $relatedRows.push($next);
        }
        $next = $next.next();
      }

      $lineItem.remove();
      $relatedRows.forEach($row => $row.remove());

      updateRemoveButtons();
      recalculateTotals();
    });

  });

  // Toggle base quantity column button 
  let baseQuantityVisible = false;

  $('#add-base-quantity').on('click', function () {
    baseQuantityVisible = !baseQuantityVisible;

    const $theadRow = $('.invoice-table thead tr');
    const $headerCells = $theadRow.find('th');

    if (baseQuantityVisible) {
      $(this).text('Hide Base Quantity Column');
      $headerCells.eq(5).text('Price');
      $('<th class="base-quantity-header">Price per Quantity</th>').insertAfter($headerCells.eq(5));

      $('.line-item').each(function () {
        $('<td class="base-quantity-cell"><input type="number" name="price_per_quantity" class="form-control price-per-quantity" step="0.01"></td>')
          .insertAfter($(this).find('td').eq(5));
      });

      $('.optional-field-row td[colspan]').attr('colspan', 10);
    } else {
      $(this).text('Show Base Quantity Column');
      $headerCells.eq(5).text('Price per unit');
      $('.base-quantity-header').remove();
      $('.base-quantity-cell').remove();
      $('.optional-field-row td[colspan]').attr('colspan', 9);
    }

    recalculateTotals();
  });

  $(document).on('change', 'select[name="price_adjustment_discount_type"]', function () {
    const selectedText = $(this).find('option:selected').text();
    const $descriptionInput = $(this).siblings('input.description');

    $descriptionInput.val(selectedText);
  });


  function recalculateTotals() {
    let subtotal = 0;
    let totalTax = 0;
    let discountAmount = 0;
    let chargeAmount = 0;
    let fixedTax = 0;

    // Calculate each line-item total
    $('#line-items .line-item').each(function () {
      const $row = $(this);
      const qty = parseFloat($row.find('.quantity').val()) || 0;
      const price = parseFloat($row.find('.price').val()) || 0;
      const pricePerQty = parseFloat($row.find('.price-per-quantity').val()) || 0;
      const taxRate = parseFloat($row.find('.tax').val()) || 0;

      // Find related discount/charge rows for this line
      const lineIndex = $row.data('line-index');
      let $discountRow = $(`#line-items .optional-field-row[data-optional-group="discount"][data-line-index="${lineIndex}"]`);
      let $chargeRow = $(`#line-items .optional-field-row[data-optional-group="charge"][data-line-index="${lineIndex}"]`);

      let discount = 0;
      if ($discountRow.length) {
        const dval = parseFloat($discountRow.find('input[name*="discount.qty"]').val()) || 0;
        const unit = $discountRow.find('select[name*="discount.unit"]').val();
        const base = (pricePerQty && !isNaN(pricePerQty) && pricePerQty !== 0)
          ? (qty * price) / pricePerQty
          : qty * price;
        discount = (unit === "%") ? base * (dval / 100) : dval;
        $discountRow.find('.optional-total[data-total-type="discount"]').text(discount.toFixed(2));
      }

      let charge = 0;
      if ($chargeRow.length) {
        const cval = parseFloat($chargeRow.find('input[name*="charge.qty"]').val()) || 0;
        const unit = $chargeRow.find('select[name*="charge.unit"]').val();
        const base = (pricePerQty && !isNaN(pricePerQty) && pricePerQty !== 0)
          ? (qty * price) / pricePerQty
          : qty * price;
        charge = (unit === "%") ? base * (cval / 100) : cval;
        $chargeRow.find('.optional-total[data-total-type="charge"]').text(charge.toFixed(2));
      }

      // Calculate line total
      let lineTotal = (pricePerQty && !isNaN(pricePerQty) && pricePerQty !== 0)
        ? (qty * price) / pricePerQty
        : qty * price;
      lineTotal = lineTotal + charge - discount;

      // Update the .total cell for this line
      $row.find('.total').text(lineTotal.toFixed(2));

      // Add to subtotal and tax
      subtotal += lineTotal;
      totalTax += lineTotal * (taxRate / 100);
    });

    // Global discount/charge/fixed tax items
    $('#line-items .discount-item').each(function () {
      const $row = $(this);
      const qty = parseFloat($row.find('.quantity').val()) || 1;
      const type = $row.find('select[name="price_adjustment_discount"]').val();
      const isPercent = $row.find('select[name="price_adjustment_unit_type"]').val() === "true";

      let value = isPercent ? subtotal * (qty / 100) : qty;

      if (type === "true") {
        discountAmount += value;
        $row.find('.total').text(`-${value.toFixed(2)}`);
      } else if (type === "false") {
        chargeAmount += value;
        $row.find('.total').text(`+${value.toFixed(2)}`);
      } else if (type === "fixedtax") {
        fixedTax += value;
        $row.find('.total').text(`+${value.toFixed(2)}`);
      }
    });

    const adjustedSubtotal = subtotal - discountAmount + chargeAmount;
    const grandTotal = adjustedSubtotal + totalTax + fixedTax;

    $('.subtotal-amount').text(adjustedSubtotal.toFixed(2));
    $('.total-tax-amount').text((totalTax + fixedTax).toFixed(2));
    $('.grand-total-amount').text(grandTotal.toFixed(2));
  }

  $(document).on(
    'input change',
    '#line-items .line-item input, #line-items .discount-item input, #line-items .discount-item select, .optional-field-row input, .optional-field-row select',
    function () {
      recalculateTotals();
    }
  );

  $('#recipient_company_id').on('change', function () {
    const selected = $(this).find('option:selected');

    $('#company_name').text(selected.data('name') || '');
    $('#company_address').text(selected.data('address') || '');
    $('#company_location').text(selected.data('registration-address') || '');
    $('#company_country').text("Philippines");

    $('#company_number').text('Company number : ' + (selected.data('company-id-number') || '-'));
    $('#company_tax_number').text('Tax number : ' + (selected.data('tax-id-number') || '-'));

    $('#recipient-preview').removeClass('d-none');
    $('#recipient_company_id').addClass('d-none');
  });

  $('#change-recipient').on('click', function (e) {
    e.preventDefault();
    $('#recipient-preview').addClass('d-none');
    $('#recipient_company_id').removeClass('d-none');
    $('#recipient_company_id').val('');
  });






}
