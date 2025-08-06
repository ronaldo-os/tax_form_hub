import { COUNTRY_OPTIONS, DISCOUNT_OPTIONS } from "./long_select_options/options";

if ( window.location.pathname === "/invoices" || window.location.pathname === "/invoices/new" || window.location.pathname.match(/^\/invoices\/\d+\/edit$/) ) {
    $(document).ready(function () {

      $('#sales-table').DataTable();
      $('#purchases-table').DataTable();
      $('#sales-archived-table').DataTable();
      $('#purchases-archived-table').DataTable();
      recalculateTotals();

      //----------------------------------------------------- INVOICE NUMBER SECTION: Add optional Field
      
      const fieldTypeMap = {
          "DeliveryDate": [
            { name: "Delivery_Date.date.12", label: "Delivery Date", type: "date", cols: 12, class: "mb-3" }
          ],
          "PaymentDueDate": [
            { name: "Payment_Due_Date.date.12", label: "Payment Due Date", type: "date", cols: 12, class: "mb-3" }
          ],
          "customsDeclarations": [
              { name: "customsDeclarations.number_1.text.12", label: "Reference Number of Customs Form No.1,9", type: "text", cols: 12, class: "mb-3" },
              { name: "customsDeclarations.number_2.text.12", label: "Reference Number of Customs Form No.2", type: "text", cols: 12, class: "mb-3" },
          ],
          "taxExchangeRateFields": [
              { name: "taxExchangeRateFields.rate.text.6", label: "Exchange rate", type: "text", cols: 6, class: "mb-3" },
              { name: "taxExchangeRateFields.currency.select(php,usd).6", label: "Currency", type: "select", cols: 6, options: ["PHP", "USD"], class: "mb-3" },
              { name: "taxExchangeRateFields.date_of_rate.text.6", label: "Date of exchange rate", type: "date", cols: 6, class: "mb-3" },
              { name: "taxExchangeRateFields.converted_tax_total.text.6", label: "Converted tax total", type: "text", cols: 6, class: "mb-3" },
              { name: "taxExchangeRateFields.converted_doc_total_inc.text.12", label: "Converted Document Total (incl taxes)", type: "text", cols: 12, class: "mb-3" },
              { name: "taxExchangeRateFields.converted_doc_total_excl.text.12", label: "Converted Document Total (excl taxes)", type: "text", cols: 12, class: "mb-3" },
          ],
          "transactionVatType": [
            { name: "transactionVatType.vat_type.select(collection,debit).12", label: "Transaction VAT Type", type: "select", cols: 12, options: ["Collection", "Debit"], class: "mb-3" }
          ],
          "orderReferenceId": [
            { name: "orderReferenceId.order_number.text.12", label: "Purchase order number", type: "text", cols: 12, class: "mb-3" }
          ],
          "orderReferenceIssueDate": [
            { name: "orderReferenceIssueDate.issue_date.date.12", label: "Purchase order number", type: "date", cols: 12, class: "mb-3" }
          ],
          "billingReferenceId": [
            { name: "billingReferenceId.reference_id.text.12", label: "Billing reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "contractDocumentReferenceId": [
            { name: "contractDocumentReferenceId.contract_number.text.12", label: "Contract number", type: "text", cols: 12, class: "mb-3" }
          ],
          "despatchDocumentReference.id": [
            { name: "despatchDocumentReference.id.shipping_reference.text.12", label: "Shipping Notice Reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "despatchDocumentReference.issueDate": [
            { name: "despatchDocumentReference.issueDate.issue_date.date.12", label: "Shipping Notice Issue Date", type: "date", cols: 12, class: "mb-3" }
          ],
          "receiptDocumentReference.id": [
            { name: "receiptDocumentReference.id.receipt_reference.text.12", label: "Goods Receipt Reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "receiptDocumentReference.issueDate": [
            { name: "receiptDocumentReference.issueDate.receipt_reference_date.date.12", label: "Goods Receipt Issue Date", type: "date", cols: 12, class: "mb-3" }
          ],
          "accountingCost": [
            { name: "accountingCost.cost_center.text.12", label: "Cost center", type: "text", cols: 12, class: "mb-3" }
          ],
          "customerPartyContactName": [
            { name: "customerPartyContactName.person_reference.text.12", label: "Person reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "additionalReferences[BOL ID]": [
            { name: "additionalReferences[BOL ID].transport_reference.text.12", label: "Transport Reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "BOLIssueDate": [
            { name: "BOLIssueDate.transport_reference_date.date.12", label: "Transport Reference Issue Date", type: "date", cols: 12, class: "mb-3" }
          ],
          "FileID": [
            { name: "FileID.file_id.text.12", label: "File Id", type: "text", cols: 12, class: "mb-3" }
          ],
          "customerAssignedId": [
            { name: "customerAssignedId.customer_id.text.12", label: "Customer account ID", type: "text", cols: 12, class: "mb-3" }
          ],
          "taxPointDate": [
            { name: "taxPointDate.tax_point_date.date.12", label: "Tax point date", type: "date", cols: 12, class: "mb-3" }
          ],
          "supplierCommissionNumber": [
            { name: "supplierCommissionNumber.number_of_seller.text.12", label: "Commission number of seller", type: "text", cols: 12, class: "mb-3" }
          ],
          "supplierPhysicalLocationValue": [
            { name: "supplierPhysicalLocationValue.data_universal_numbering_system.text.12", label: "Data universal numbering system", type: "text", cols: 12, class: "mb-3" }
          ],
          "deliveryTerms": [
            { name: "deliveryTerms.delivery_terms.text.12", label: "Delivery Terms", type: "text", cols: 12, class: "mb-3" }
          ],
          "InternimHours": [
            { name: "InternimHours.interim_hours.text.12", label: "Interim Hours", type: "text", cols: 12, class: "mb-3" }
          ],
          "BookingNumber": [
            { name: "BookingNumber.booking_number.text.12", label: "Booking Number", type: "text", cols: 12, class: "mb-3" }
          ],
          "PaymentReference": [
            { name: "PaymentReference.payment_reference.text.12", label: "Payment Reference", type: "text", cols: 12, class: "mb-3" }
          ],
          "promisedDeliveryPeriod": [
            { name: "promisedDeliveryPeriod.delivery_period.text.12", label: "Delivery period", type: "text", cols: 12, class: "mb-3" }
          ],
          "ClearanceClave": [
            { name: "ClearanceClave.clearance_clave.text.12", label: "Clearance Clave", type: "text", cols: 12, class: "mb-3" }
          ]
      };

      $('#optionalField').on('change', function () {
        const key = $(this).val();
        if (!key) return;

        const $container = $('#invoice_details_parent_div #optional_fields_container');

        if ($container.find(`[data-optional-group="${key}"]`).length > 0) {
          alert("This group is already added.");
          $(this).val('');
          return;
        }

        const fields = fieldTypeMap[key];
        if (!fields || !Array.isArray(fields)) return;

        let groupHtml = `
          <div class="mb-3 position-relative border rounded p-3 pt-3 optional-group" data-optional-group="${key}">
            <button type="button" class="btn btn-sm btn-outline-danger rounded position-absolute top-0 end-0 m-2 remove-group">×</button>
            <div class="row">
        `;

        fields.forEach(field => {
          const colClass = `col-md-${field.cols || 6} ${field.class || ""}`;
          let inputHtml = "";

          if (field.type === "select") {
            inputHtml = `
              <select class="form-select optional-input" data-field-name="${field.name}">
                ${field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('')}
              </select>`;
          } else if (field.type === "textarea") {
            inputHtml = `<textarea class="form-control optional-input" data-field-name="${field.name}"></textarea>`;
          } else {
            inputHtml = `<input type="${field.type}" class="form-control optional-input" data-field-name="${field.name}">`;
          }

          groupHtml += `
            <div class="${colClass}">
              <label class="form-label">${field.label}</label>
              ${inputHtml}
            </div>
          `;
        });

        groupHtml += `
            </div>
          </div>
        `;

        $container.append(groupHtml);
        $(this).val('');
        updateInvoiceInfoJSON();
      });


      // Remove group inside #invoice_details_parent_div
      $(document).on('click', '#invoice_details_parent_div .remove-group', function () {
        $(this).closest('[data-optional-group]').remove();
        updateInvoiceInfoJSON();
      });

      // Track input changes in optional fields inside #invoice_details_parent_div
      $(document).on('input change', '#invoice_details_parent_div .optional-input, #invoice_details_parent_div [data-optional-group] input, #invoice_details_parent_div [data-optional-group] select, #invoice_details_parent_div [data-optional-group] textarea', function () {
        updateInvoiceInfoJSON();
      });

      // Update hidden field from fields inside #invoice_details_parent_div
      function updateInvoiceInfoJSON() {
        const data = {};

        $('#invoice_details_parent_div [data-optional-group]').each(function () {
          const groupKey = $(this).data('optional-group');
          const inputs = $(this).find('input, select, textarea');

          inputs.each(function () {
            const name = $(this).data('field-name') || $(this).attr('name');
            const value = $(this).val();

            if (name) {
              data[name] = value;
            }
          });
        });

        $('#optional_fields_json').val(JSON.stringify(data));
      }

    });


    //----------------------------------------------------- PAYMENT TERMS FIELD 

    const payment_terms_fieldTypeMap = {
    paymentterms: [
        { name: "paymentterms.discount_percent.text.6", label: "Discount Percent", type: "text", cols: 6 },
        { name: "paymentterms.surcharge_percent.text.6", label: "Surcharge Percent", type: "text", cols: 6 },
        { name: "paymentterms.settelement_start_date.date.6", label: "Settlement Start Date", type: "date", cols: 6 },
        { name: "paymentterms.penalty_start_date.date.6", label: "Penalty Start Date", type: "date", cols: 6 },
        { name: "paymentterms.settlement_end_date.date.6", label: "Settlement End Date", type: "date", cols: 6 },
        { name: "paymentterms.penalty_end_date.date.6", label: "Penalty End Date", type: "date", cols: 6 },
        { name: "paymentterms.note.textarea.12", label: "Note", type: "textarea", cols: 12 },
    ],
    cash: [
        { name: "cash.cash.text_only.12", label: "Cash Payment", type: "text_only", cols: 12 }
    ],
    check: [
        { name: "check.check.text_only.12", label: "Check Payment", type: "text_only", cols: 12 },
    ],
    bank: [
        { name: "bank.name.text.12", label: "Bank name", type: "text", cols: 12 },
        { name: "bank.sortcode.text.6", label: "Sort Code", type: "text", cols: 6 },
        { name: "bank.account_number.text.6", label: "Account number", type: "text", cols: 6 },
        { name: "bank.account_holder_name.text.12", label: "Account holder name (optional) ", type: "text", cols: 12 },
        { name: "bank.street_name.text.12", label: "Street name (optional)", type: "text", cols: 12 },
        { name: "bank.additional_street_name.text.12", label: "Additional street name (optional)", type: "text", cols: 12 },
        { name: "bank.building_number.text.6", label: "Building number (optional)", type: "text", cols: 6 },
        { name: "bank.city.text.6", label: "City (optional)", type: "text", cols: 6 },
        { name: "bank.zip_code.text.12", label: "Postal/Zip code (optional)", type: "text", cols: 12 },
        { name: "bank.state.text.12", label: "State/Region (optional)", type: "text", cols: 12 },
        { name: "bank.address_line.text.12", label: "Address line (optional)", type: "text", cols: 12 },
        { name: "bank.country.text.12", label: "Country (optional)", type: "text", cols: 12 },
        { name: "bank.note.text.12", label: "Payment note", type: "text", cols: 12 },
    ],
    bank_card: [
        { name: "bank_card.bank_card.text_only.6", label: "Bank Card", type: "text_only", cols: 6 },
    ],
    debit: [
        { name: "debit.name.text.12", label: "Bank name", type: "text", cols: 12 },
        { name: "debit.sortcode.text.6", label: "Sort Code", type: "text", cols: 6 },
        { name: "debit.account_number.text.6", label: "Account number", type: "text", cols: 6 },
        { name: "debit.account_holder_name.text.12", label: "Account holder name (optional) ", type: "text", cols: 12 },
        { name: "debit.street_name.text.12", label: "Street name (optional)", type: "text", cols: 12 },
        { name: "debit.additional_street_name.text.12", label: "Additional street name (optional)", type: "text", cols: 12 },
        { name: "debit.building_number.text.6", label: "Building number (optional)", type: "text", cols: 6 },
        { name: "debit.city.text.6", label: "City (optional)", type: "text", cols: 6 },
        { name: "debit.zip_code.text.12", label: "Postal/Zip code (optional)", type: "text", cols: 12 },
        { name: "debit.state.text.12", label: "State/Region (optional)", type: "text", cols: 12 },
        { name: "debit.address_line.text.12", label: "Address line (optional)", type: "text", cols: 12 },
        { name: "debit.country.text.12", label: "Country (optional)", type: "text", cols: 12 },
        { name: "debit.note.text.12", label: "Payment note", type: "text", cols: 12 },
    ],
    bic_iban: [
        { name: "bic_iban.bic_swift.text.4", label: "BIC/SWIFT", type: "text", cols: 4 },
        { name: "bic_iban.iban.text.8", label: "IBAN", type: "text", cols: 8 },
        { name: "bic_iban.note.text.12", label: "Payment note", type: "text", cols: 12 },
    ],
    };

    $('#payment_terms_select').on('change', function () {
      const key = $(this).val();
      const keyText = $(this).find('option:selected').text().trim();
      if (!key) return;

      // Prevent duplicates
      if ($(`#payment_terms_parent_div [data-group-key="${key}"]`).length > 0) {
        alert("This payment term group is already added.");
        $(this).val('');
        return;
      }

      const fields = payment_terms_fieldTypeMap[key];
      if (!fields || !Array.isArray(fields)) return;

      let groupHtml = `
        <div class="mb-3 border rounded p-3 pt-3 payment-term-group" data-group-key="${key}">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <h5 class="mb-0">${keyText}</h5>
            <button type="button" class="btn btn-sm btn-outline-danger remove-group">×</button>
          </div>
          <div class="row">
      `;

      fields.forEach(field => {
        const colClass = `col-md-${field.cols || 6} ${field.class || ""}`;
        let inputHtml = "";

        if (field.type === "text_only") {
          inputHtml = `<p class="mb-0">${field.label}</p>`;
        } else {
          if (field.type === "select") {
            inputHtml = `
              <select class="form-select payment-term-input" data-field-name="${field.name}">
                ${field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('')}
              </select>`;
          } else if (field.type === "textarea") {
            inputHtml = `<textarea class="form-control payment-term-input" data-field-name="${field.name}"></textarea>`;
          } else {
            inputHtml = `<input type="${field.type}" class="form-control payment-term-input" data-field-name="${field.name}">`;
          }

          groupHtml += `
            <div class="${colClass} mb-3">
              <label class="form-label">${field.label}</label>
              ${inputHtml}
            </div>
          `;
        }
      });

      groupHtml += `
          </div>
        </div>
      `;

      $('#payment_terms_parent_div').append(groupHtml);
      $(this).val('');
      updatePaymentTermsJSON();
    });

    // Handle input changes in payment term fields
    $(document).on('input change', '.payment-term-input', function () {
      updatePaymentTermsJSON();
    });

    // Remove group
    $(document).on('click', '.remove-group', function () {
      $(this).closest('.payment-term-group').remove();
      updatePaymentTermsJSON();
    });

    // Update hidden JSON field
    function updatePaymentTermsJSON() {
      const result = {};

      $('.payment-term-group').each(function () {
        const groupKey = $(this).data('group-key');
        const fields = {};

        $(this).find('.payment-term-input').each(function () {
          const name = $(this).data('field-name');
          const value = $(this).val();
          if (name) fields[name] = value;
        });

        result[groupKey] = fields;
      });

      $('#payment_terms_json').val(JSON.stringify(result));
    }

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
      $(`#${type}_location_id`).val('');
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
      const lineItemCount = $('#line-items .line-item').length;
      const discountItemCount = $('#line-items .discount-item').length;

      // Hide all remove buttons by default
      $('#line-items .remove-line').hide();

      // If there is more than one item in total, show all remove buttons
      if (lineItemCount + discountItemCount > 1) {
        if (lineItemCount === 1 && discountItemCount) {
          $('#line-items .discount-item .remove-line').show();
        } else {
          $('#line-items .remove-line').show();
        }
      }
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

    function getLineItemHTML(new_record_id) {
      return `
        <tr class="line-item" data-line-index="${new_record_id}">
          <td><button type="button" class="btn btn-sm btn-outline-primary toggle-dropdown">+</button></td>
          <td><input type="text" name="invoice[line_items_attributes][${new_record_id}][item_id]" class="form-control item-id"></td>
          <td><input type="text" name="invoice[line_items_attributes][${new_record_id}][description]" class="form-control description"></td>
          <td><input type="number" name="invoice[line_items_attributes][${new_record_id}][quantity]" class="form-control quantity" value="1"></td>
          <td><input type="text" name="invoice[line_items_attributes][${new_record_id}][unit]" class="form-control unit" value="pcs"></td>
          <td><input type="number" name="invoice[line_items_attributes][${new_record_id}][price]" class="form-control price" step="0.01"></td>
          <td><input type="number" name="invoice[line_items_attributes][${new_record_id}][tax]" class="form-control tax" step="0.01"></td>
          <td>
            <select name="invoice[line_items_attributes][${new_record_id}][recurring]" class="form-select recurring">
              <option value="no">No</option>
              <option value="every_month">Every month</option>
              <option value="every_quarter">Every quarter</option>
              <option value="every_year">Every year</option>
            </select>
          </td>
          <td class="text-end total">0.00</td>
          <td>
            <input type="hidden" name="invoice[line_items_attributes][${new_record_id}][_destroy]" value="false">
            <button type="button" class="btn btn-sm btn-outline-danger remove-line">&minus;</button>
          </td>
        </tr>
        <tr class="dropdown_per_line hidden">
          <td colspan="3">
            <select name="additional_field_${new_record_id}" id="additional_field_${new_record_id}" class="no-label form-select">
              <option value="">Add optional field</option>
              ${getDropdownOptions()}
            </select>
          </td>
          <td colspan="6"></td>
        </tr>
      `;
    }

    // In your event listener for adding a line
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
      { name: "discount.discount_type.select(DISCOUNT_OPTIONS).2", label: "Discount type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
      { name: "discount.discount_type_edit.text.4", label: "Edit type (if needed)", type: "text", cols: 4 },
      { name: "discount.qty.text.2", label: "Quantity", type: "text", cols: 2 },
      { name: "discount.unit.select(php,%).2", label: "Unit", type: "select", options: ["PHP", "%"], cols: 2 },
      { name: "discount.total.text_only.2", label: "Total", type: "text_only", cols: 2 },
    ],
    charge: [
      { name: "charge.charge_type.select(DISCOUNT_OPTIONS).2", label: "Charge type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
      { name: "charge.charge_type_edit.text.4", label: "Edit type (if needed)", type: "text", cols: 4 },
      { name: "charge.qty.text.2", label: "Quantity", type: "text", cols: 2 },
      { name: "charge.unit.select(php,%).2", label: "Unit", type: "select", options: ["PHP", "%"], cols: 2 },
      { name: "charge.total.text_only.2", label: "Total", type: "text_only", cols: 2 },
    ],
    bolid: [
      { name: "bolid.transport_reference.text.4", label: "Transport Reference", type: "text", cols: 4 }
    ],
    fileid: [
      { name: "fileid.file_id.text.4", label: "File ID", type: "text", cols: 4 }
    ],
    taxexemptionreason: [
      { name: "taxexemptionreason.tax_exemption_reason.text.4", label: "Tax exemption reason", type: "text", cols: 4 }
    ],
    modelname: [
      { name: "modelname.model_name.text.4", label: "Model name", type: "text", cols: 4 }
    ],
    hsnsac: [
      { name: "hsnsac.hsn_sac.select(hsn,sac).4", label: "HSN/SAC", type: "select", options: ["HSN", "SAC"], cols: 4 },
      { name: "hsnsac.qty.text.4", label: "Quantity", type: "text", cols: 4 },
    ],
    documentreference: [
      { name: "documentreference.purchase_order_number.text.4", label: "Purchase order number", type: "text", cols: 4 }
    ],
    documentlinereference: [
      { name: "documentlinereference.purchase_order_line_number.text.4", label: "Purchase order line number", type: "text", cols: 4 }
    ],
    accountingcost: [
      { name: "accountingcost.cost_center.text.4", label: "Cost center", type: "text", cols: 4 }
    ],
    deliveryaddress: [
      { name: "deliveryaddress.country_origin.select(COUNTRY_OPTIONS).4", label: "Country/Region", type: "select", options: COUNTRY_OPTIONS, cols: 4 },
      { name: "deliveryaddress.postbox.text.4", label: "Postbox", type: "text", cols: 4 },
      { name: "deliveryaddress.street.text.4", label: "Street", type: "text", cols: 4 },
      { name: "deliveryaddress.number.text.4", label: "Number", type: "text", cols: 4 },
      { name: "deliveryaddress.locality_name.text.4", label: "Locality name", type: "text", cols: 4 },
      { name: "deliveryaddress.postal_zipcode.text.4", label: "Postal/ZIP", type: "text", cols: 4 },
      { name: "deliveryaddress.city.text.4", label: "City", type: "text", cols: 4 },
      { name: "deliveryaddress.location_id.text.4", label: "Location Id", type: "text", cols: 4 },
    ],
    actualdeliverydate: [
      { name: "actualdeliverydate.delivery_date.date.4", label: "Delivery Date", type: "date", cols: 4 }
    ],
    buyersitemidentification: [
      { name: "buyersitemidentification.buyer_material_number.text.4", label: "Buyer material number", type: "text", cols: 4 }
    ],
    origincountry: [
      { name: "origincountry.country_origin.select(COUNTRY_OPTIONS).4", label: "Country of origin", type: "select", options: COUNTRY_OPTIONS, cols: 4 }
    ],
    eccn: [
      { name: "eccn.commodity_classification.text.4", label: "Commodity classification: ECCN", type: "text", cols: 4 }
    ],
    eangtin: [
      { name: "eangtin.ean_gtin.text.4", label: "EAN/GTIN", type: "text", cols: 4 }
    ],
    incoterms: [
      { name: "incoterms.delivery_terms.text.4", label: "Delivery Terms", type: "text", cols: 4 }
    ],
    manufacturename: [
      { name: "manufacturename.manufacture_name.text.4", label: "Manufacture name", type: "text", cols: 4 }
    ],
    trackingid: [
      { name: "trackingid.freight_order_number.text.4", label: "Freight order number", type: "text", cols: 4 }
    ],
    serialID: [
      { name: "serialID.serial_id.text.4", label: "Serial number", type: "text", cols: 4 }
    ],
    linenote: [
      { name: "linenote.note.text.4", label: "Notes", type: "text", cols: 4 }
    ],
    despatchlinedocumentreference: [
      { name: "despatchlinedocumentreference.shipping_notice_reference.text.4", label: "Shipping Notice Reference", type: "text", cols: 4 }
    ],
    despatchlineiddocumentreference: [
      { name: "despatchlineiddocumentreference.shipping_notice_line_reference.text.4", label: "Shipping Notice Line Reference", type: "text", cols: 4 }
    ],
    receiptlinedocumentreference: [
      { name: "receiptlinedocumentreference.receipt_reference.text.4", label: "Goods Receipt Reference", type: "text", cols: 4 }
    ],
    receiptlineiddocumentreference: [
      { name: "receiptlineiddocumentreference.receipt_line_reference.text.4", label: "Goods Receipt Line Reference", type: "text", cols: 4 }
    ],
  };

  $(document).on('change', 'select[name*="[optional_fields][discount.discount_type]"], select[name*="[optional_fields][charge.charge_type]"]', function () {
    const $select = $(this);
    const selectedValue = $select.val();
    const $rowGroup = $select.closest('tr.optional-field-row');

    let targetName = '';

    if ($select.attr('name').includes('discount.discount_type')) {
      targetName = 'discount.discount_type_edit';
    } else if ($select.attr('name').includes('charge.charge_type')) {
      targetName = 'charge.charge_type_edit';
    }

    if (targetName !== '') {
      const $editInput = $rowGroup.find(`input[name*="[optional_fields][${targetName}]"]`);
      if ($editInput.length > 0) {
        $editInput.val(selectedValue).trigger('input');
      }
    }
  });


  $(document).on('change', 'select[id^="additional_field_"]', function () {
    const $select = $(this);
    const selectedKey = $select.val();
    const selectedText = $select.find("option:selected").text();
    if (!selectedKey) return;
    
    const $dropdownRow = $select.closest('tr.dropdown_per_line');
    const $lineItemRow = $dropdownRow.siblings(`.line-item[data-line-index]`).filter(function () {
      return $(this).data('line-index') === parseInt($select.attr('id').split('_').pop());
    });
    const rowIndex = $lineItemRow.data('line-index');
    if (rowIndex === undefined) {
      console.warn("Missing data-line-index for optional field");
      return;
    }

    const fields = discount_fieldTypeMap[selectedKey];
    if (!Array.isArray(fields)) return;

    // Prevent duplicate optional fields of the same type for the same line
    const existing = $(`#line-items .optional-field-row[data-line-index="${rowIndex}"][data-optional-group="${selectedKey}"]`);
    if (existing.length > 0) return;

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

      const inputName = `invoice[line_items_attributes][${rowIndex}][optional_fields][${field.name}]`;

      if (field.type === "select") {
        const optionsHtml = field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('');
        inputHtml = `<select name="${inputName}" class="form-select"${field.disabled ? ' disabled' : ''}>${optionsHtml}</select>`;
      } else if (field.type === "textarea") {
        inputHtml = `<textarea name="${inputName}" class="form-control"${field.disabled ? ' disabled' : ''}></textarea>`;
      } else if (field.type === "text_only") {
        inputHtml = `<span class="form-control-plaintext optional-total" data-total-type="${selectedKey}" data-line-index="${rowIndex}">0.00</span>`;
      } else {
        inputHtml = `<input type="${field.type}" name="${inputName}" class="form-control"${field.disabled ? ' disabled' : ''}>`;
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

  $('#add-discount-row').on('click', function () {
    const newRow = `
      <tr class="discount-item">
        <td class="align-top" colspan="2">
          <select class="form-select price-adjustment-unit" data-field="unit">
            <option value="discount">Discount</option>
            <option value="charge">Charge</option>
            <option value="fixedtax">Fixed Tax</option>
          </select>
        </td>
        <td class="align-top" colspan="2">
          <input type="text" class="form-control description-edit mb-2" placeholder="Description" data-field="description_edit">
          <select class="form-select reason-code" data-field="description">
            <option value="" disabled selected>Choose reason code</option>
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
          <input type="number" class="form-control amount" value="1" data-field="amount">
        </td>
        <td class="align-top">
          <select class="form-select unit-type" data-field="unit_type">
            <option value="false">PHP</option>
            <option value="true">%</option>
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
    updateDiscountsJSON();
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
    updateDiscountsJSON();
  });

  // Track changes
  $('#line-items').on('input change', '.discount-item input, .discount-item select', function () {
    updateDiscountsJSON();
  });


  });

  // Update hidden field for price_adjustments
  function updateDiscountsJSON() {
    const discounts = [];

    $('.discount-item').each(function () {
      const $row = $(this);

      const unit = $row.find('.price-adjustment-unit').val();
      const description = $row.find('.reason-code').val();
      const description_edit = $row.find('.description-edit').val();
      const amount = parseFloat($row.find('.amount').val()) || 0;
      const unit_type_raw = $row.find('.unit-type').val();
      const unit_type = unit_type_raw === "true" ? "%" : "PHP";

      discounts.push({
        unit,
        description,
        description_edit,
        amount,
        unit_type
      });
    });

    $('#price_adjustments_json').val(JSON.stringify(discounts));
  }

  $(window).on('load', function () {
    recalculateTotals();
    updatePaymentTermsJSON();
    updateDiscountsJSON();
    $('#optional_fields_json').val(function(_, val) {
      const parts = val.match(/(?:[^\s"]+|"[^"]*")+/g);
      const obj = {};
      for (let i = 0; i < parts.length; i += 2)
        obj[parts[i]] = parts[i + 1];
      return JSON.stringify(obj);
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
        $('<td class="base-quantity-cell"><input type="number" name="invoice[price_per_quantity]" class="form-control price-per-quantity" step="0.01"></td>')
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

  // Update discount type input when select changes
  $(document).on('change', 'select[name*="[optional_fields][discount.discount_type.select"], select[name*="[optional_fields][charge.charge_type.select"]', function () {
    const selectedValue = $(this).val();
    const selectName = $(this).attr('name');

    const match = selectName.match(/invoice\[line_items_attributes\]\[(\d+)\]/);
    if (!match) return;
    const index = match[1];

    let inputName = '';

    if (selectName.includes('discount.discount_type.select')) {
      inputName = `invoice[line_items_attributes][${index}][optional_fields][discount.discount_type_edit.text.4]`;
    } else if (selectName.includes('charge.charge_type.select')) {
      inputName = `invoice[line_items_attributes][${index}][optional_fields][charge.charge_type_edit.text.4]`;
    } else {
      return; 
    }

    $(`input[name="${inputName}"]`).val(selectedValue);
  });
  
  // Update description input when reason code is selected
  $(document).on('change', 'select.reason-code', function () {
    const selectedText = $(this).find('option:selected').text();
    const $descriptionInput = $(this).siblings('input.description-edit');
    $descriptionInput.val(selectedText);
  });


  function recalculateTotals() {
    let subtotal = 0;
    let totalTax = 0;
    let discountAmount = 0;
    let chargeAmount = 0;
    let fixedTax = 0;

    $('#line-items .line-item').each(function () {
      const $row = $(this);
      const qty = parseFloat($row.find('.quantity').val()) || 0;
      const price = parseFloat($row.find('.price').val()) || 0;
      const pricePerQty = parseFloat($row.find('.price-per-quantity').val()) || 0;
      const taxRate = parseFloat($row.find('.tax').val()) || 0;

      const lineIndex = $row.data('line-index');

      // Base line value before adjustments
      let base = (pricePerQty && pricePerQty !== 0)
        ? (qty * price) / pricePerQty
        : qty * price;

      // --- Discount Calculation ---
      let discount = 0;
      const $discountRows = $(`.optional-field-row[data-optional-group="discount"][data-line-index="${lineIndex}"]`);
      $discountRows.each(function () {
        const $dRow = $(this);
        const dval = parseFloat($dRow.find('input[name*="discount.qty"]').val()) || 0;
        const unit = $dRow.find('select[name*="discount.unit"]').val();
        const dAmount = (unit === "%") ? base * (dval / 100) : dval;
        discount += dAmount;
        $dRow.find('.optional-total[data-total-type="discount"]').text(dAmount.toFixed(2));
      });

      // --- Charge Calculation ---
      let charge = 0;
      const $chargeRows = $(`.optional-field-row[data-optional-group="charge"][data-line-index="${lineIndex}"]`);
      $chargeRows.each(function () {
        const $cRow = $(this);
        const cval = parseFloat($cRow.find('input[name*="charge.qty"]').val()) || 0;
        const unit = $cRow.find('select[name*="charge.unit"]').val();
        const cAmount = (unit === "%") ? base * (cval / 100) : cval;
        charge += cAmount;
        $cRow.find('.optional-total[data-total-type="charge"]').text(cAmount.toFixed(2));
      });

      // Final line total
      let lineTotal = base + charge - discount;
      $row.find('.total').text(lineTotal.toFixed(2));

      // Accumulate overall totals
      subtotal += lineTotal;
      totalTax += lineTotal * (taxRate / 100);
    });

    // --- Global price adjustments ---
    $('#line-items .discount-item').each(function () {
      const $row = $(this);

      const type = $row.find('select.price-adjustment-unit').val(); 
      const isPercent = $row.find('select.unit-type').val() === "true";
      const qty = parseFloat($row.find('.amount').val()) || 0;

      let value = isPercent ? subtotal * (qty / 100) : qty;

      if (type === "discount") {
        discountAmount += value;
        $row.find('.total').text(`-${value.toFixed(2)}`);
      } else if (type === "charge") {
        chargeAmount += value;
        $row.find('.total').text(`+${value.toFixed(2)}`);
      } else if (type === "fixedtax") {
        fixedTax += value;
        $row.find('.total').text(`+${value.toFixed(2)}`);
      } else {
        // fallback for unexpected values
        $row.find('.total').text(value.toFixed(2));
      }
    });

    const adjustedSubtotal = subtotal - discountAmount + chargeAmount;
    const grandTotal = adjustedSubtotal + totalTax + fixedTax;

    const totalsJson = {
      subtotal: adjustedSubtotal.toFixed(2),
      tax: (totalTax + fixedTax).toFixed(2),
      grand_total: grandTotal.toFixed(2)
    };

    $('#total_amount_json').val(JSON.stringify(totalsJson));
    $('.subtotal-amount').text(totalsJson.subtotal);
    $('.total-tax-amount').text(totalsJson.tax);
    $('.grand-total-amount').text(totalsJson.grand_total);
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

  // Handle location selection changes
  $(".location-select").on("change", function () {
    const type = $(this).data("type");
    const selectedId = $(this).val();
    const hiddenField = $(`#${type}_location_id`);

    if (hiddenField.length) {
      hiddenField.val(selectedId);
    }
  });


  // INVOICE EDIT PAGE JS 

    const selected = $('#recipient_company_id option:selected');
    if (selected.val()) {
      $('#recipient_company_id').trigger('change');
    }

    $('.location-select').each(function () {
      const $select = $(this);
      const type = $select.data('type');

      if ($select.val()) {
        $select.trigger('change');
        $(`.location-toggle-btn[data-type="${type}"]`).hide();
      }
    });

    $('.location-toggle-btn').each(function () {
      const $btn = $(this);
      const type = $btn.data('type');
      const selectId = `#${type.toLowerCase().replace(/ /g, '_')}_select`;
      const wrapperId = `#${type.toLowerCase().replace(/ /g, '_')}_selector_wrapper`;
      const $select = $(selectId);

      if ($select.length && $select.val() && !$(`${wrapperId}`).is(':visible')) {
        $btn.trigger('click');
      }
    });

    // Display Invoice Info
    $(function () {
      const rawData = $('#optional_fields_container').attr('data-invoice-info');
      let invoiceInfo;

      try {
        invoiceInfo = JSON.parse(rawData);
      } catch (e) {
        console.error("Failed to parse invoice_info", e);
        return;
      }

      const $container = $('#invoice_details_parent_div #optional_fields_container');
      const groups = {};

      Object.entries(invoiceInfo).forEach(([fullKey, value]) => {
        // Parse the group key (e.g., before first dot)
        const parts = fullKey.split('.');
        const groupKey = parts[0]; // e.g., Delivery_Date or FileID
        const inputType = parts[1] || 'text';
        const cols = parts[2] || '12';

        if (!groups[groupKey]) {
          groups[groupKey] = [];
        }

        // Extract human label
        let label;
        const bracketMatch = fullKey.match(/\[(.*?)\]/);
        if (bracketMatch) {
          label = bracketMatch[1];
        } else {
          const baseKey = fullKey.split('.')[0]; // fallback
          label = baseKey.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
        }

        groups[groupKey].push({
          fullKey,
          label,
          type: inputType === 'text' || inputType === 'date' || inputType === 'number' ? inputType : 'text',
          cols,
          value
        });
      });

      // Render
      Object.entries(groups).forEach(([groupKey, fields]) => {
        if ($container.find(`[data-optional-group="${groupKey}"]`).length > 0) return;

        let groupHtml = `
          <div class="mb-3 position-relative border rounded p-3 pt-3 optional-group" data-optional-group="${groupKey}">
            <button type="button" class="btn btn-sm btn-outline-danger rounded position-absolute top-0 end-0 m-2 remove-group">×</button>
            <div class="row">
        `;

        fields.forEach(field => {
          groupHtml += `
            <div class="col-md-${field.cols}">
              <label class="form-label">${field.label}</label>
              <input type="${field.type}" class="form-control optional-input" data-field-name="${field.fullKey}" value="${field.value}">
            </div>
          `;
        });

        groupHtml += `
            </div>
          </div>
        `;

        $container.append(groupHtml);
      });
    });

    // Display Delivery Details if any input has value
    $(function () {
      const $collapse = $('#delivery_details_parent_div');
      if (!$collapse.length) return;

      const hasValue = $collapse.find('input, select').filter(function () {
        return $(this).val()?.trim();
      }).length > 0;

      if (hasValue) {
        $collapse.collapse('show');
        $('[data-bs-target="#delivery_details_parent_div"]').attr('aria-expanded', 'true');
      }
    });

    // Display Footer Notes if textarea has value
    $(function () {
      const $footerCollapse = $('#footer_wrapper_parent_div');
      if (!$footerCollapse.length) return;

      const hasFooterNote = $footerCollapse.find('textarea').filter(function () {
        return $(this).val()?.trim();
      }).length > 0;

      if (hasFooterNote) {
        $footerCollapse.show();
      }
    });

    // Function to generate line item HTML
    function getLineItemHTML(index) {
      return `
        <tr class="line-item" data-line-index="${index}">
          <td><button type="button" class="btn btn-sm btn-outline-primary toggle-dropdown">+</button></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][item_id]" class="form-control item-id"></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][description]" class="form-control description"></td>
          <td><input type="number" name="invoice[line_items_attributes][${index}][quantity]" class="form-control quantity" value="1"></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][unit]" class="form-control unit" value="pcs"></td>
          <td><input type="number" name="invoice[line_items_attributes][${index}][price]" class="form-control price" step="0.01"></td>
          <td><input type="number" name="invoice[line_items_attributes][${index}][tax]" class="form-control tax" step="0.01"></td>
          <td>
            <select name="invoice[line_items_attributes][${index}][recurring]" class="form-select recurring">
              <option value="no">No</option>
              <option value="every_month">Every month</option>
              <option value="every_quarter">Every quarter</option>
              <option value="every_year">Every year</option>
            </select>
          </td>
          <td class="text-end total">0.00</td>
          <td>
            <button type="button" class="btn btn-sm btn-outline-danger remove-line">−</button>
          </td>
        </tr>
        <tr class="dropdown_per_line" data-line-index="${index}">
          <td colspan="3">
            <select name="additional_field_${index}" id="additional_field_${index}" class="no-label form-select optional-type">
              <option value="">Add optional field</option>
              <option value="discount">Discount</option>
              <option value="charge">Charge (e.g. freight)</option>
              <option value="bolid">Transport Reference</option>
              <option value="fileid">File Id</option>
              <option value="taxexemptionreason">Tax exemption reason</option>
              <option value="modelname">Model name</option>
              <option value="hsnsac">HSN/SAC</option>
              <option value="documentreference">Purchase order number</option>
              <option value="documentlinereference">Purchase order line number</option>
              <option value="accountingcost">Cost center</option>
              <option value="deliveryaddress">Delivery Address</option>
              <option value="actualdeliverydate">Delivery Date</option>
              <option value="buyersitemidentification">Buyer material number</option>
              <option value="origincountry">Country of origin</option>
              <option value="eccn">Commodity classification: ECCN</option>
              <option value="eangtin">EAN/GTIN</option>
              <option value="incoterms">Delivery Terms</option>
              <option value="manufacturename">Manufacture name</option>
              <option value="trackingid">Freight order number</option>
              <option value="serialID">Serial number</option>
              <option value="linenote">Notes</option>
              <option value="despatchlinedocumentreference">Shipping Notice Reference</option>
              <option value="despatchlineiddocumentreference">Shipping Notice Line Reference</option>
              <option value="receiptlinedocumentreference">Goods Receipt Reference</option>
              <option value="receiptlineiddocumentreference">Goods Receipt Line Reference</option>
            </select>
          </td>
          <td colspan="6" class="optional-fields-container"></td>
        </tr>
      `;
    }

    // Initialize line items from JSON data and show optional fields
    $(function () {
      const $lineItems = $('#line-items');
      const rawJson = $lineItems.attr('data-line-items');
      if (!rawJson) return;

      let data;
      try {
        data = JSON.parse(rawJson);
      } catch (err) {
        console.error("Line items JSON parsing failed:", err);
        return;
      }

      data.forEach((item, i) => {
        const $html = $(getLineItemHTML(i));
        $lineItems.append($html);

        $html.find('.item-id').val(item.item_id);
        $html.find('.description').val(item.description);
        $html.find('.quantity').val(item.quantity);
        $html.find('.unit').val(item.unit);
        $html.find('.price').val(item.price);
        $html.find('.tax').val(item.tax);
        $html.find('.recurring').val(item.recurring);
        $html.find('input[name$="[_destroy]"]').val(item._destroy);

        if (item.optional_fields) { $html.find('.toggle-dropdown').text('–'); }

        if (item.optional_fields) {
          Object.entries(item.optional_fields).forEach(([groupKey, fields]) => {
            const $optionalRow = $(`
              <tr class="optional-field-row" data-optional-group="${groupKey}" data-line-index="${i}">
                <td colspan="9">
                  <div class="p-2 border rounded bg-light mb-2">
                    <p class="fs-5 mb-3 d-flex justify-content-between align-items-center text-uppercase">
                      ${groupKey.replace(/_/g, ' ')}
                      <button type="button" class="btn btn-sm btn-outline-danger remove-group ms-2">×</button>
                    </p>
                    <div class="row g-3"></div>
                  </div>
                </td>
              </tr>
            `);

            const $fieldRow = $optionalRow.find('.row');
            const entries = Object.entries(fields).reverse();
            const isTotalGroup = ['charge', 'discount'].includes(groupKey);

            entries.forEach(([rawKey, val], index, array) => {
              const name = `invoice[line_items_attributes][${i}][optional_fields][${groupKey}.${rawKey}]`;

              // Determine value type
              let value = '';
              let type = 'text';
              let cols = 4;

              if (typeof val === 'string') {
                value = val;
              } else if (typeof val === 'object') {
                value = val.value || '';
                type = val.type || 'text';
                cols = val.columns || 4;
              }

              // Get columns from .N suffix
              const colMatch = rawKey.match(/\.(\d+)$/);
              if (colMatch) cols = parseInt(colMatch[1]);

              // Extract label (second segment only)
              const labelSegment = rawKey.split('.')[0] || '';
              const formattedLabel = labelSegment.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

              const colClass = `col-md-${cols}`;

              if (rawKey.includes('select(')) {
                const match = rawKey.match(/select\((.*?)\)/);
                const optionSource = match?.[1] || '';
                let options = [];

                if (optionSource === "DISCOUNT_OPTIONS") {
                  options = DISCOUNT_OPTIONS;
                } else if (optionSource === "COUNTRY_OPTIONS") {
                  options = COUNTRY_OPTIONS;
                } else {
                  options = optionSource.split(',').map(opt => opt.trim());
                }

                $fieldRow.append(`
                  <div class="${colClass} mb-3">
                    <label class="form-label">${formattedLabel}</label>
                    <select name="${name}" class="form-select">
                      ${options.map(opt => `<option value="${opt}" ${opt === value ? 'selected' : ''}>${opt}</option>`).join('')}
                    </select>
                  </div>
                `);
              } else {
                $fieldRow.append(`
                  <div class="${colClass} mb-3">
                    <label class="form-label">${formattedLabel}</label>
                    <input type="${type}" name="${name}" class="form-control" value="${value}">
                  </div>
                `);
              }

              // Add TOTAL field if it's the last in charge/discount
              const isLast = index === array.length - 1;
              if (isLast && isTotalGroup) {
                $fieldRow.append(`
                  <div class="col-md-2 mb-3">
                    <label class="form-label text-start w-100">Total</label>
                    <span class="form-control-plaintext optional-total" data-total-type="${groupKey}" data-line-index="${i}">0.00</span>
                  </div>
                `);
              }
            });

            $lineItems.find(`.dropdown_per_line[data-line-index="${i}"]`).before($optionalRow);
          });

          recalculateTotals();
        }
      });
    });

    // Render payment terms from JSON
    $(function () {
      let raw = $('#payment_terms_json_edit').val();
      let data;

      try {
        data = JSON.parse(raw);
        renderPaymentTerms(data);
      } catch (e) {
        console.error("Invalid JSON in payment_terms_json:", e.message, raw);
      }
    });

    function renderPaymentTerms(data) {
      const $container = $('#payment_terms_parent_div');
      if ($container.length === 0) {
        console.warn('#payment_terms_parent_div not found');
        return;
      }

      $container.empty();

      Object.entries(data).forEach(([groupKey, fields]) => {
        const layout = payment_terms_fieldTypeMap[groupKey];
        if (!layout) return;

        const $group = $(`
          <div class="mb-3 border rounded p-3 pt-3 payment-term-group" data-group-key="${groupKey}">
            <div class="d-flex justify-content-between align-items-center mb-3">
              <h5 class="mb-0">${formatGroupName(groupKey)}</h5>
              <button type="button" class="btn btn-sm btn-outline-danger remove-group">×</button>
            </div>
            <div class="row"></div>
          </div>
        `);

        const $row = $group.find('.row');

        layout.forEach(field => {
          const value = fields[field.name] || '';
          const colClass = `col-md-${field.cols} mb-3`;

          let $inputGroup;
          if (field.type === 'text_only') {
            $inputGroup = $(`
              <div class="${colClass}">
                <label class="form-label">${field.label}</label>
                <div class="form-control-plaintext payment-term-text-only" data-field-name="${field.name}">${value}</div>
              </div>
            `);
          } else if (field.type === 'textarea') {
            $inputGroup = $(`
              <div class="${colClass}">
                <label class="form-label">${field.label}</label>
                <textarea class="form-control payment-term-input" data-field-name="${field.name}">${value}</textarea>
              </div>
            `);
          } else {
            $inputGroup = $(`
              <div class="${colClass}">
                <label class="form-label">${field.label}</label>
                <input type="${field.type}" class="form-control payment-term-input" data-field-name="${field.name}" value="${value}">
              </div>
            `);
          }

          $row.append($inputGroup);
        });

        $container.append($group);
      });
    }

    function formatGroupName(key) {
      return key === 'bank' ? 'Bank Account' : (key === 'cash' ? 'Cash payment' : key.charAt(0).toUpperCase() + key.slice(1));
    }

    // Render price adjustments from JSON
    $(function () {
      const reasonOptions = [
        "Bank Charges", "Customs Duties", "Repair Costs", "Attorney Fees", "Taxes",
        "Late Delivery", "Freight Costs", "Reason Unknown", "Price Change",
        "Early payment allowance adjustment", "Quantity Discount", "Pricing Discount",
        "Volume Discount", "Agreed Discount", "Expediting fee", "Currency exchange differences"
      ];

      function buildReasonOptions(selected) {
        let options = '<option value="" disabled>Choose reason code</option>';
        reasonOptions.forEach(reason => {
          const isSelected = reason === selected ? ' selected' : '';
          options += `<option value="${reason}"${isSelected}>${reason}</option>`;
        });
        return options;
      }

      function renderAdjustmentRow(adjustment) {
        const amount = adjustment.amount ?? 0;
        const unit = adjustment.unit ?? "discount"; // new: maps to discount/charge/fixedtax
        const unitType = adjustment.unit_type === "%" ? "true" : "false"; // maps to % or PHP
        const description = adjustment.description ?? "";
        const descriptionEdit = adjustment.description_edit ?? "";
        const totalFormatted = `${unitType === "true" ? "+" : "+"}${parseFloat(amount).toFixed(2)}`;

        return `
          <tr class="discount-item">
            <td class="align-top" colspan="2">
              <select class="form-select price-adjustment-unit" data-field="unit">
                <option value="discount"${unit === "discount" ? " selected" : ""}>Discount</option>
                <option value="charge"${unit === "charge" ? " selected" : ""}>Charge</option>
                <option value="fixedtax"${unit === "fixedtax" ? " selected" : ""}>Fixed Tax</option>
              </select>
            </td>
            <td class="align-top" colspan="2">
              <input type="text" class="form-control description-edit mb-2" placeholder="Description" data-field="description_edit" value="${descriptionEdit}">
              <select class="form-select reason-code" data-field="description">
                ${buildReasonOptions(description)}
              </select>
            </td>
            <td class="align-top">
              <input type="number" class="form-control amount" value="${amount}" data-field="amount">
            </td>
            <td class="align-top">
              <select class="form-select unit-type" data-field="unit_type">
                <option value="false"${unitType === "false" ? " selected" : ""}>PHP</option>
                <option value="true"${unitType === "true" ? " selected" : ""}>%</option>
              </select>
            </td>
            <td class="align-top"></td>
            <td class="align-top"></td>
            <td class="align-top text-end total">${totalFormatted}</td>
            <td class="align-top">
              <button type="button" class="btn btn-sm btn-outline-danger remove-line">−</button>
            </td>
          </tr>
        `;
      }

      // Fetch JSON and render
      let price_adjustments_raw = $('#price_adjustments_json_edit').val();
      let priceAdjustments = [];

      try {
        if (price_adjustments_raw) {
          priceAdjustments = JSON.parse(price_adjustments_raw);
        }
      } catch (e) {
        console.error("Invalid JSON in #price_adjustments_json_edit:", e.message, price_adjustments_raw);
        return;
      }

      let $lastRow = $(".line-item, .optional-field-row").last();

      priceAdjustments.forEach(adjustment => {
        const html = renderAdjustmentRow(adjustment);
        $lastRow.after(html);
        $lastRow = $lastRow.next();
      });
    });


  
}