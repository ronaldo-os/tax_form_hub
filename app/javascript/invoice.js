import { COUNTRY_OPTIONS, DISCOUNT_OPTIONS, INVOICE_INFO_OPTIONAL_FIELDS, OPTIONAL_FIELDS } from "./long_select_options/options";
import { initCompanySelector } from "./invoice_company_selector";

// Variable to hold the cleanup function for company selector
let companySelectorCleanup = null;

const initInvoiceForm = () => {
  if (!document.getElementById('company_search_input')) return;

  // Cleanup previous company selector listener if exists
  if (companySelectorCleanup) {
    companySelectorCleanup();
    companySelectorCleanup = null;
  }

  // Cleanup previous document listeners for invoice form
  $(document).off('.invoice_form');

  // Clear attachment-related fields when form initializes
  const fileInput = document.getElementById('attachments');
  if (fileInput) {
    fileInput.value = '';
  }
  const previewContainer = document.getElementById('new_attachments_preview');
  if (previewContainer) {
    previewContainer.innerHTML = '';
  }

  // universal functions
  function formatCurrency(value) {
    if (value === null || value === undefined || value === '') return '0.00';
    let num = parseFloat(String(value).replace(/,/g, ''));
    if (isNaN(num)) num = 0;
    return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  function getThemeAwareBadgeClass(text, color) {
    const currentTheme = document.documentElement.getAttribute('data-theme') || 'light';
    const badgeClass = currentTheme === 'dark' ? 
      `bg-${color} text-white` : 
      `bg-${color}-subtle text-${color}`;
    return `<span class="badge ${badgeClass} small">${text}</span>`;
  }

  function buildTaxOptions(selectedRate) {
    if (!window.TAX_RATES) return '<option value="0">0%</option>';
    let options = `<option value="" disabled ${selectedRate === undefined || selectedRate === null ? 'selected' : ''}>Select Tax</option>`;

    window.TAX_RATES.forEach(tax => {
      const isSelected = selectedRate !== undefined && selectedRate !== null && parseFloat(selectedRate) === parseFloat(tax.rate);
      const displayRate = parseFloat(tax.rate).toString() + '%';
      options += `<option value="${tax.rate}" data-name="${tax.name}" ${isSelected ? 'selected' : ''}>${displayRate}</option>`;
    });
    options += `<option value="custom" class="fw-bold text-primary">+ Manage/Add Custom Tax</option>`;
    return options;
  }

  function buildUnitOptions(selectedUnit) {
    if (!window.UNIT_OPTIONS || window.UNIT_OPTIONS.length === 0) {
      let opts = `<option value="pcs" ${selectedUnit === 'pcs' ? 'selected' : ''}>pcs</option>`;
      opts += `<option value="custom" class="fw-bold text-primary">+ Manage/Add Unit</option>`;
      return opts;
    }
    let baseOpts = '';
    window.UNIT_OPTIONS.forEach(u => {
      baseOpts += `<option value="${u.name}" ${u.name === selectedUnit ? 'selected' : ''}>${u.name}</option>`;
    });
    if (selectedUnit && selectedUnit !== 'custom' && !window.UNIT_OPTIONS.find(u => u.name === selectedUnit)) {
      baseOpts = `<option value="${selectedUnit}" selected>${selectedUnit} (Legacy)</option>` + baseOpts;
    }
    baseOpts += `<option value="custom" class="fw-bold text-primary">+ Manage/Add Unit</option>`;
    return baseOpts;
  }

  function parseCurrency(value) {
    if (!value) return 0;
    return parseFloat(String(value).replace(/,/g, '')) || 0;
  }

  // Function to generate line item HTML (Unified)
  function getLineItemHTML(index, selectedTax = null) {
    return `
        <tr class="line-item" data-line-index="${index}">
          <td><button type="button" class="btn btn-sm btn-outline-primary toggle-dropdown">+</button></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][item_id]" class="form-control item-id" required></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][description]" class="form-control description" required></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][quantity]" class="form-control quantity" value="1" required></td>
          <td><select name="invoice[line_items_attributes][${index}][unit]" class="form-select unit" required>${buildUnitOptions('pcs')}</select></td>
          <td><input type="text" name="invoice[line_items_attributes][${index}][price]" class="form-control price" required></td>
          <td><select name="invoice[line_items_attributes][${index}][tax]" class="form-select tax" required>${buildTaxOptions(selectedTax)}</select></td>
          <td class="text-end total">0.00</td>
          <td>
            <button type="button" class="btn btn-sm btn-outline-danger remove-line">−</button>
          </td>
        </tr>
        <tr class="dropdown_per_line hidden" data-line-index="${index}">
          <td colspan="3">
            <select name="additional_field_${index}" id="additional_field_${index}" class="no-label form-select optional-type">
              <option value="">Add optional field</option>
              ${buildOptions(OPTIONAL_FIELDS)}
            </select>
          </td>
          <td colspan="6" class="optional-fields-container"></td>
        </tr>
      `;
  }

  let lineIndex = 1; // Global counter for new lines

  // Credit Note Invoice Selector Logic (Dropdown)
  $(document).on('change.invoice_form', '#credit_note_original_invoice_id', function () {
    const invoiceId = $(this).val();
    const invoiceNumber = $(this).find('option:selected').text();

    if (invoiceId) {
      $('#original_invoice_status_badge').html(`<span class="badge bg-success">Linked: ${invoiceNumber}</span>`);
    } else {
      $('#original_invoice_status_badge').html('<span class="badge bg-secondary">Not Linked</span>');
    }
  });

  function updateRemoveButtons() {
    const lineItemCount = $('#line-items .line-item').length;
    const discountItemCount = $('#line-items .discount-item').length;

    // Hide all remove buttons by default
    $('#line-items .remove-line').hide();

    // If there is more than one item in total, show all remove buttons
    if (lineItemCount + discountItemCount > 1) {
      $('#line-items .remove-line').show();
    }
  }


  companySelectorCleanup = initCompanySelector();
  recalculateTotals();

  // Unit Management Logic
  function updateUnitList() {
    const $list = $('#unit-list');
    $list.empty();
    if (!window.UNIT_OPTIONS) return;
    window.UNIT_OPTIONS.forEach(u => {
      const deleteBtn = u.custom ? `<button class="btn btn-sm btn-outline-danger delete-unit-btn" data-id="${u.id}">&times;</button>` : '';
      $list.append(`<li class="list-group-item d-flex justify-content-between align-items-center">${u.name} ${deleteBtn}</li>`);
    });
  }

  $(document).on('change.invoice_form', '.unit', function () {
    if ($(this).val() === 'custom') {
      const modalId = 'unitManagementModal';
      const modalElement = document.getElementById(modalId);
      if (modalElement) {
        const modal = new bootstrap.Modal(modalElement);
        updateUnitList();
        modal.show();
      }
      // Revert selection to avoid staying on 'custom'
      // If it's a new line, default to pcs. If editing, ideally we'd revert to previous, 
      // but for now pcs is a safe fallback for the UI state.
      $(this).val('pcs');
    }
  });

  $('#add-unit-btn').on('click', function () {
    const name = $('#new-unit-name').val();
    if (!name) return;
    $('#unit-error').text("");
    $.ajax({
      url: '/units',
      method: 'POST',
      dataType: 'json',
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      data: { unit: { name: name } },
      success: function (resp) {
        window.UNIT_OPTIONS.push({ id: resp.id, name: resp.name, custom: true });
        updateUnitList();
        $('#new-unit-name').val('');
        $('.unit').each(function () {
          const val = $(this).val();
          $(this).html(buildUnitOptions(val));
          $(this).val(val);
        });
      },
      error: function (err) {
        $('#unit-error').text("Failed to add unit. It might already exist.");
      }
    });
  });

  $(document).on('click', '.delete-unit-btn', function () {
    const id = $(this).data('id');
    $.ajax({
      url: `/units/${id}`,
      method: 'DELETE',
      dataType: 'json',
      headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
      success: function () {
        window.UNIT_OPTIONS = window.UNIT_OPTIONS.filter(u => u.id != id);
        updateUnitList();
        $('.unit').each(function () {
          const val = $(this).val();
          $(this).html(buildUnitOptions(val));
          $(this).val(val);
        });
      }
    });
  });

  // Build options for optional fields dropdown
  function buildOptions(fields) {
    return Object.entries(fields)
      .map(([value, label]) => `<option value="${value}">${label}</option>`)
      .join("");
  }

  $("#additional_field_0").html(buildOptions(OPTIONAL_FIELDS));
  $(".invoice_info_select").html(buildOptions(INVOICE_INFO_OPTIONAL_FIELDS));

  // Suggest invoice number
  $(document).on('click', '#use_suggested_invoice_number', function (e) {
    e.preventDefault();
    const suggested = $(this).text().trim();
    $('input[name="invoice[invoice_number]"]').val(suggested);
  });


  //----------------------------------------------------- INVOICE NUMBER SECTION: Add optional Field

  const fieldTypeMap = {
    "DeliveryDate": [
      { name: "Delivery_Date.delivery_date.date.12", label: "Delivery Date", type: "date", cols: 12, class: "mb-3" }
    ],
    "PaymentDueDate": [
      { name: "Payment_Due_Date.payment_due_date.date.12", label: "Payment Due Date", type: "date", cols: 12, class: "mb-3" }
    ],
    "customsDeclarations": [
      { name: "customsDeclarations.reference_number_of_customs_from_No_1.text.12", label: "Reference Number of Customs Form No.1", type: "text", cols: 12, class: "mb-3" },
      { name: "customsDeclarations.reference_number_of_customs_from_No_2.text.12", label: "Reference Number of Customs Form No.2", type: "text", cols: 12, class: "mb-3" },
    ],
    "taxExchangeRateFields": [
      { name: "taxExchangeRateFields.exchange_rate.text.7", label: "Exchange rate", type: "text", cols: 7, class: "mb-3" },
      { name: "taxExchangeRateFields.currency.select(php,usd,eur,jpy).5", label: "Currency", type: "select", cols: 5, options: ["PHP", "USD", "EUR", "JPY"], class: "mb-3" },
      { name: "taxExchangeRateFields.date_of_exchange_rate.text.7", label: "Date of exchange rate", type: "date", cols: 7, class: "mb-3" },
      { name: "taxExchangeRateFields.converted_tax_total.text.5", label: "Converted tax total", type: "text", cols: 5, class: "mb-3" },
      { name: "taxExchangeRateFields.converted_document_total_(incl taxes).text.12", label: "Converted Document Total (incl taxes)", type: "text", cols: 12, class: "mb-3" },
      { name: "taxExchangeRateFields.converted_document_total_(excl taxes).text.12", label: "Converted Document Total (excl taxes)", type: "text", cols: 12, class: "mb-3" },
    ],
    "transactionVatType": [
      { name: "transactionVatType.transaction_vat_type.select(collection,debit).12", label: "Transaction VAT Type", type: "select", cols: 12, options: ["Collection", "Debit"], class: "mb-3" }
    ],
    "orderReferenceId": [
      { name: "orderReferenceId.purchase_order_number.text.12", label: "Purchase order number", type: "text", cols: 12, class: "mb-3" }
    ],
    "orderReferenceIssueDate": [
      { name: "orderReferenceIssueDate.purchase_order_issue_date.date.12", label: "Purchase order issue date", type: "date", cols: 12, class: "mb-3" }
    ],
    "billingReferenceId": [
      { name: "billingReferenceId.billing_reference.text.12", label: "Billing reference", type: "text", cols: 12, class: "mb-3" }
    ],
    "contractDocumentReferenceId": [
      { name: "contractDocumentReferenceId.contract_number.text.12", label: "Contract number", type: "text", cols: 12, class: "mb-3" }
    ],
    "despatchDocumentReference.id": [
      { name: "despatchDocumentReference.shipping_notice_reference.text.12", label: "Shipping Notice Reference", type: "text", cols: 12, class: "mb-3" }
    ],
    "despatchDocumentReference.issueDate": [
      { name: "despatchDocumentReference.shipping_notice_issue_date.date.12", label: "Shipping Notice Issue Date", type: "date", cols: 12, class: "mb-3" }
    ],
    "receiptDocumentReference.id": [
      { name: "receiptDocumentReference.goods_receipt_reference.text.12", label: "Goods Receipt Reference", type: "text", cols: 12, class: "mb-3" }
    ],
    "receiptDocumentReference.issueDate": [
      { name: "receiptDocumentReference.goods_receipt_issue_date.date.12", label: "Goods Receipt Issue Date", type: "date", cols: 12, class: "mb-3" }
    ],
    "accountingCost": [
      { name: "accountingCost.cost_center.text.12", label: "Cost center", type: "text", cols: 12, class: "mb-3" }
    ],
    "customerPartyContactName": [
      { name: "customerPartyContactName.person_reference.text.12", label: "Person reference", type: "text", cols: 12, class: "mb-3" }
    ],
    "transportReference": [
      { name: "transport_reference.text.12", label: "Transport Reference", type: "text", cols: 12, class: "mb-3" }
    ],
    "transportReferenceIssueDate": [
      { name: "transport_reference_issue_date.date.12", label: "Transport Reference Issue Date", type: "date", cols: 12, class: "mb-3" }
    ],
    "FileID": [
      { name: "FileID.file_id.text.12", label: "File Id", type: "text", cols: 12, class: "mb-3" }
    ],
    "customerAssignedId": [
      { name: "customerAssignedId.customer_account_id.text.12", label: "Customer account ID", type: "text", cols: 12, class: "mb-3" }
    ],
    "taxPointDate": [
      { name: "taxPointDate.tax_point_date.date.12", label: "Tax point date", type: "date", cols: 12, class: "mb-3" }
    ],
    "supplierCommissionNumber": [
      { name: "supplierCommissionNumber.commision_number_of_seller.text.12", label: "Commission number of seller", type: "text", cols: 12, class: "mb-3" }
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
      showFlashMessage("This group is already added.", "danger");
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
  $(document).on('click.invoice_form', '#invoice_details_parent_div .remove-group', function () {
    $(this).closest('[data-optional-group]').remove();
    updateInvoiceInfoJSON();
  });

  // Track input changes in optional fields inside #invoice_details_parent_div
  $(document).on('input.invoice_form change.invoice_form', '#invoice_details_parent_div .optional-input, #invoice_details_parent_div [data-optional-group] input, #invoice_details_parent_div [data-optional-group] select, #invoice_details_parent_div [data-optional-group] textarea', function () {
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



  //----------------------------------------------------- PAYMENT TERMS FIELD 

  const payment_terms_fieldTypeMap = {
    payment_terms: [
      { name: "payment_terms.discount_percent.text.6", label: "Discount Percent", type: "text", cols: 6 },
      { name: "payment_terms.surcharge_percent.text.6", label: "Surcharge Percent", type: "text", cols: 6 },
      { name: "payment_terms.settelement_start_date.date.6", label: "Settlement Start Date", type: "date", cols: 6 },
      { name: "payment_terms.penalty_start_date.date.6", label: "Penalty Start Date", type: "date", cols: 6 },
      { name: "payment_terms.settlement_end_date.date.6", label: "Settlement End Date", type: "date", cols: 6 },
      { name: "payment_terms.penalty_end_date.date.6", label: "Penalty End Date", type: "date", cols: 6 },
      { name: "payment_terms.note.textarea.12", label: "Note", type: "textarea", cols: 12 },
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
      showFlashMessage("This payment term group is already added.", "danger");
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
  $(document).on('input.invoice_form change.invoice_form', '.payment-term-input', function () {
    updatePaymentTermsJSON();
  });

  // Remove group
  $(document).on('click.invoice_form', '.remove-group', function () {
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

    $('#payment_terms_json, #payment_terms_json_edit').val(JSON.stringify(result));
  }

  // ----------------------------------------------------- DELIVERY DETAILS BUTTON TOGGLE

  var $btn = $('[data-bs-toggle="collapse"][data-bs-target="#delivery_details_parent_div"]');
  var $target = $($btn.data('bs-target'));

  $target.on('show.bs.collapse hide.bs.collapse', function (e) {
    var symbol = e.type === 'show' ? '−' : '+';
    $btn.text(symbol + ' Delivery Details');
  });

  //----------------------------------------------------- PAYMENT TERMS LOCATIONS BUTTON TOGGLE

  $(document).on('click.invoice_form', '.location-toggle-btn', function () {
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
        showFlashMessage("Failed to fetch location details.", "danger");
        $(`#${type}_details`).hide();
      }
    });
  });


  //----------------------------------------------------- ADD FOOTER BUTTON TOGGLE

  // Use a direct execution instead of document.ready inside the init function
  (function () {
    const $button = $('.add-footer-toggle-btn');
    const $target = $('#footer_wrapper_parent_div');
    const $notes = $('#invoice_footer_notes');
    const notesVal = $notes.val() || '';

    if (notesVal.trim() !== '') {
      $target.show();
      $button.text('− Remove footer notes');
    } else {
      $target.hide();
      $button.text('+ Add footer notes');
    }

    // Toggle action - Use off().on() to prevent duplicate bindings if not using document delegation, 
    // but since these are specific elements found by selector, just ensuring we don't double bind
    $button.off('click').on('click', function () {
      $target.slideToggle(300, function () {
        const isVisible = $target.is(':visible');
        $button.text(isVisible ? '− Remove footer notes' : '+ Add footer notes');
      });
    });
  })();

  (function () {

    const $select = $('#initial_delivery_details_country');


    if ($select.length) {
      $.each(COUNTRY_OPTIONS, function (i, country) {
        $select.append($('<option>', {
          value: country,
          text: country
        }));
      });
    }

    // Event listener for adding a line - using delegation for robustness
    $(document).off('click.invoice_form', '#add-line').on('click.invoice_form', '#add-line', function () {
      $('#line-items').append(getLineItemHTML(lineIndex++));
      updateRemoveButtons();
      recalculateTotals();
    });

    $(document).on('click.invoice_form', '.toggle-dropdown', function () {
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

      if ($toggleRows.length === 0) return;

      const firstRow = $toggleRows[0];
      const shouldShow = !($(firstRow).is(':visible') && !$(firstRow).hasClass('hidden'));

      $toggleRows.forEach(row => {
        const $row = $(row);
        if (shouldShow) {
          $row.show().removeClass('hidden');
        } else {
          $row.hide();
        }
      });
      $btn.text(shouldShow ? '−' : '+');
    });





    // Initialization   
    updateRemoveButtons();

    window.discount_fieldTypeMap = {
      discount: [
        { name: "discount.discount_type.select(DISCOUNT_OPTIONS).2", label: "Discount type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
        { name: "discount.edit_type_(if needed).text.4", label: "Edit type (if needed)", type: "text", cols: 4 },
        { name: "discount.amount.text.2", label: "Amount", type: "text", cols: 2 },
        { name: "discount.unit.select(php,%).2", label: "Unit", type: "select", options: ["PHP", "%"], cols: 2 },
        { name: "discount.total.text_only.2", label: "Total", type: "text_only", cols: 2 },
      ],
      charge: [
        { name: "charge.charge_type.select(DISCOUNT_OPTIONS).2", label: "Charge type", type: "select", options: DISCOUNT_OPTIONS, cols: 2 },
        { name: "charge.edit_type_(if needed).text.4", label: "Edit type (if needed)", type: "text", cols: 4 },
        { name: "charge.amount.text.2", label: "Amount", type: "text", cols: 2 },
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
        { name: "hsnsac.quantity.text.4", label: "Quantity", type: "text", cols: 4 },
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
        { name: "deliveryaddress.country/region.select(COUNTRY_OPTIONS).4", label: "Country/Region", type: "select", options: COUNTRY_OPTIONS, cols: 4 },
        { name: "deliveryaddress.postbox.text.4", label: "Postbox", type: "text", cols: 4 },
        { name: "deliveryaddress.street.text.4", label: "Street", type: "text", cols: 4 },
        { name: "deliveryaddress.number.text.4", label: "Number", type: "text", cols: 4 },
        { name: "deliveryaddress.locality_name.text.4", label: "Locality name", type: "text", cols: 4 },
        { name: "deliveryaddress.postal/zipcode.text.4", label: "Postal/ZIP", type: "text", cols: 4 },
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
        { name: "origincountry.country_of_origin.select(COUNTRY_OPTIONS).4", label: "Country of origin", type: "select", options: COUNTRY_OPTIONS, cols: 4 }
      ],
      eccn: [
        { name: "eccn.commodity_classification:_ECCN.text.4", label: "Commodity classification: ECCN", type: "text", cols: 4 }
      ],
      eangtin: [
        { name: "eangtin.ean/gtin.text.4", label: "EAN/GTIN", type: "text", cols: 4 }
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
      note: [
        { name: "note.notes.text.4", label: "Notes", type: "text", cols: 4 }
      ],
      despatchlinedocumentreference: [
        { name: "despatchlinedocumentreference.shipping_notice_reference.text.4", label: "Shipping Notice Reference", type: "text", cols: 4 }
      ],
      despatchlineiddocumentreference: [
        { name: "despatchlineiddocumentreference.shipping_notice_line_reference.text.4", label: "Shipping Notice Line Reference", type: "text", cols: 4 }
      ],
      receiptlinedocumentreference: [
        { name: "receiptlinedocumentreference.goods_receipt_reference.text.4", label: "Goods Receipt Reference", type: "text", cols: 4 }
      ],
      receiptlineiddocumentreference: [
        { name: "receiptlineiddocumentreference.goods_receipt_line_reference.text.4", label: "Goods Receipt Line Reference", type: "text", cols: 4 }
      ],
    };



    $(document).on('change.invoice_form', 'select[name*="[optional_fields][discount.discount_type]"], select[name*="[optional_fields][charge.charge_type]"]', function () {
      const $select = $(this);
      const selectedValue = $select.val();
      const $rowGroup = $select.closest('tr.optional-field-row');

      let targetName = '';

      if ($select.attr('name').includes('discount.discount_type')) {
        targetName = 'discount.edit_type_(if needed)';
      } else if ($select.attr('name').includes('charge.charge_type')) {
        targetName = 'charge.edit_type_(if needed)';
      }

      if (targetName !== '') {
        const $editInput = $rowGroup.find(`input[name*="[optional_fields][${targetName}]"]`);
        if ($editInput.length > 0) {
          $editInput.val(selectedValue).trigger('input');
        }
      }
    });

    $(document).on('change.invoice_form', 'select[id^="additional_field_"]', function () {
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

      const existing = $(`#line-items .optional-field-row[data-line-index="${rowIndex}"][data-optional-group="${selectedKey}"]`);
      if (existing.length > 0) return;

      let newRowHtml = `
      <tr class="optional-field-row bg-light" data-optional-group="${selectedKey}" data-line-index="${rowIndex}">
        <td></td><td></td>
    `;

      fields.forEach(field => {
        let inputHtml = '';
        const inputName = `invoice[line_items_attributes][${rowIndex}][optional_fields][${field.name}]`;
        const placeholder = field.label ? ` placeholder="${field.label}"` : '';

        if (field.type === "select") {
          const optionsHtml = field.options.map(opt => `<option value="${opt}">${opt}</option>`).join('');
          inputHtml = `
          <select name="${inputName}" class="form-select form-select-sm"${field.disabled ? ' disabled' : ''}>
            <option value="" disabled selected>${field.label}</option>
            ${optionsHtml}
          </select>
        `;
        } else if (field.type === "textarea") {
          inputHtml = `
          <textarea 
            name="${inputName}" 
            class="form-control form-control-sm"
            ${placeholder}
            ${field.disabled ? ' disabled' : ''}></textarea>
        `;
        } else if (field.type === "text_only") {
          inputHtml = `
          <span class="form-control-plaintext text-end optional-total" 
            data-total-type="${selectedKey}" 
            data-line-index="${rowIndex}">0.00</span>
          <input type="hidden" 
            name="${inputName}" 
            class="form-control optional-total-input"
            ${field.disabled ? ' disabled' : ''}>
        `;
        } else if (field.type === "date") {
          inputHtml = `
          <input 
            type="text"
            name="${inputName}"
            class="form-control form-control-sm flatpickr-date"
            placeholder="${field.label}"
            autocomplete="off"
            readonly
          />
        `;
        } else {
          inputHtml = `
          <input 
            type="${field.type}" 
            name="${inputName}" 
            class="form-control form-control-sm"
            ${placeholder}
            ${field.disabled ? ' disabled' : ''}>
        `;
        }

        newRowHtml += `<td>${inputHtml}</td>`;
      });

      const totalCols = 7;
      if (fields.length < totalCols) {
        const emptyCols = totalCols - fields.length - 1;
        for (let i = 0; i < emptyCols; i++) {
          newRowHtml += `<td></td>`;
        }
      }

      newRowHtml += `
      <td class="text-end">
        <button type="button" class="btn btn-sm btn-outline-danger remove-group">-</button>
      </td>
    </tr>`;

      $dropdownRow.before(newRowHtml);
      $select.val('');
      updateCurrencyFields();
      recalculateTotals();

      // ✅ Initialize Flatpickr for date fields (only show on click)
      $dropdownRow.prev().find('.flatpickr-date').each(function () {
        const fp = flatpickr(this, {
          dateFormat: "Y-m-d",
          allowInput: false,
          clickOpens: false,
        });

        $(this).off('click').on('click', function () {
          fp.open();
        });
      });
    });



    $(document).on('click.invoice_form', '.remove-group', function () {
      $(this).closest('tr.optional-field-row').remove();
      updateCurrencyFields();
    });


    // Remove dynamically added group
    /* Duplicate handler removed - already handled by the handler above */



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
          <input type="text" class="form-control amount" value="1" data-field="amount">
        </td>
        <td class="align-top">
          <select class="form-select unit-type" data-field="unit_type">
            <option value="false"><span class="currency_type">PHP</span></option>
            <option value="true">%</option>
          </select>
        </td>
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

      if ($lineItem.hasClass('line-item')) {
        let $next = $lineItem.next();
        const $relatedRows = [];

        while ($next.length && !$next.hasClass('line-item')) {
          if ($next.hasClass('dropdown_per_line') || $next.hasClass('optional-field-row')) {
            $relatedRows.push($next);
          }
          $next = $next.next();
        }
        $relatedRows.forEach($row => $row.remove());
      }

      $lineItem.remove();

      updateRemoveButtons();
      recalculateTotals();
      updateDiscountsJSON();
    });

    // Track changes
    $('#line-items').on('input change', 'input, select, textarea', function () {
      updateDiscountsJSON();
    });


  })();

  // Update hidden field for price_adjustments
  function updateDiscountsJSON() {
    const discounts = [];

    $('.discount-item').each(function () {
      const $row = $(this);

      const type = ($row.find('.price-adjustment-unit').val() || "").trim();
      const description = ($row.find('.reason-code').val() || "").trim();
      const description_edit = ($row.find('.description-edit').val() || "").trim();
      const amount = parseCurrency($row.find('.amount').val());

      const unit_raw = $row.find('.unit-type').val();
      const unit = unit_raw === "true" ? "%" : "PHP";

      const total = ($row.find('.total').text().trim() || "0.00").replace(/[^\d.-]/g, "");

      discounts.push({
        type,
        description: description || null,
        description_edit: description_edit || "",
        amount,
        unit,
        total
      });
    });

    $('#price_adjustments_json, #price_adjustments_json_edit').val(JSON.stringify(discounts));
  }



  // Toggle base quantity column button 
  // Toggle base quantity column button 
  let baseQuantityVisible = false;

  $('#add-base-quantity').on('click', function () {
    baseQuantityVisible = !baseQuantityVisible;

    const $table = $('.invoice-table');
    const $theadRow = $table.find('thead tr');
    const $headerCells = $theadRow.find('th');

    if (baseQuantityVisible) {
      $(this).text('Hide Base Quantity Column');
      $headerCells.eq(5).text('Price');
      $('<th class="base-quantity-header">Price per Quantity</th>').insertAfter($headerCells.eq(5));

      // Add input column to each main line item
      $table.find('tr.line-item').each(function () {
        $('<td class="base-quantity-cell"><input type="number" name="invoice[price_per_quantity]" class="form-control price-per-quantity" step="0.01"></td>')
          .insertAfter($(this).find('td').eq(5));
      });

      // Add an empty <td> at the second-to-last position for NON-line-item rows only
      $table.find('tr').not('.line-item').each(function () {
        const $tds = $(this).find('td');
        if ($tds.length > 2 && !$(this).find('.empty-added').length) {
          $('<td class="empty-added"></td>').insertBefore($tds.last());
        }
      });

      $('.optional-field-row td[colspan]').attr('colspan', 10);
    } else {
      $(this).text('Show Base Quantity Column');
      $headerCells.eq(5).text('Price per unit');
      $('.base-quantity-header').remove();
      $('.base-quantity-cell').remove();
      $('.empty-added').remove();
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
      inputName = `invoice[line_items_attributes][${index}][optional_fields][discount.edit_type_(if needed).text.4]`;
    } else if (selectName.includes('charge.charge_type.select')) {
      inputName = `invoice[line_items_attributes][${index}][optional_fields][charge.edit_type_(if needed).text.4]`;
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
    updateDiscountsJSON();
  });


  function recalculateTotals() {
    let subtotal = 0;
    let totalTax = 0;
    let discountAmount = 0;
    let chargeAmount = 0;
    let fixedTax = 0;
    let taxBreakdown = {};

    $('#line-items .line-item').each(function () {
      const $row = $(this);
      const qty = parseFloat($row.find('.quantity').val()) || 0;
      const price = parseCurrency($row.find('.price').val());
      const pricePerQty = parseCurrency($row.find('.price-per-quantity').val()) || 0; // Use parseCurrency for safety
      const $taxSelect = $row.find('.tax');
      const taxRate = parseFloat($taxSelect.val()) || 0;
      const taxRateVal = $taxSelect.val();
      const taxName = (taxRateVal !== null && taxRateVal !== "" && taxRateVal !== undefined) ? parseFloat(taxRateVal).toString() + "%" : "Taxes";

      const lineIndex = $row.data('line-index');

      // Base line value before adjustments
      let base = (pricePerQty && pricePerQty !== 0)
        ? (qty * price) / pricePerQty
        : qty * price;

      // Find associated optional rows (siblings until next line item)
      const $optionalRows = $row.nextUntil('.line-item', '.optional-field-row');

      // --- Discount Calculation ---
      let discount = 0;
      let discountTax = 0;
      const $discountRows = $optionalRows.filter('[data-optional-group="discount"]');
      $discountRows.each(function () {
        const $dRow = $(this);
        const dval = parseCurrency($dRow.find('input[name*="discount.amount"]').val()) || 0;
        const unit = $dRow.find('select[name*="discount.unit.select(php,%).2"]').val();
        const dType = $dRow.find('select[name*="discount.discount_type"]').val();

        const dAmount = (unit === "%") ? base * (dval / 100) : dval;

        if (dType === "Taxes") {
          discountTax += dAmount;
        } else {
          discount += dAmount;
        }

        // Format discount total
        $dRow.find('.optional-total[data-total-type="discount"]').text(formatCurrency(dAmount));
        $dRow.find('.optional-total-input').val(dAmount.toFixed(2));
      });


      // --- Charge Calculation ---
      let charge = 0;
      let extraTax = 0;
      const $chargeRows = $optionalRows.filter('[data-optional-group="charge"]');
      $chargeRows.each(function () {
        const $cRow = $(this);
        const cval = parseCurrency($cRow.find('input[name*="charge.amount"]').val()) || 0;
        const unit = $cRow.find('select[name*="charge.unit.select(php,%).2"]').val();
        const cType = $cRow.find('select[name*="charge.charge_type"]').val();

        const cAmount = (unit === "%") ? base * (cval / 100) : cval;

        if (cType === "Taxes") {
          extraTax += cAmount;
        } else {
          charge += cAmount;
        }

        // Format charge total
        $cRow.find('.optional-total[data-total-type="charge"]').text(formatCurrency(cAmount));
        $cRow.find('.optional-total-input').val(cAmount.toFixed(2));
      });


      // Final line total
      let lineTotal = base + charge - discount;
      let lineTotalwithTax = lineTotal + extraTax + (lineTotal * (taxRate / 100)) - discountTax;
      $row.find('.total').text(formatCurrency(lineTotalwithTax));


      let $totalInput = $row.find('input[name*="[total]"]');
      if ($totalInput.length === 0) {
        $totalInput = $('<input>', {
          type: 'hidden',
          name: `invoice[line_items_attributes][${lineIndex}][total]`,
          class: 'line-total-input'
        });
        $row.append($totalInput);
      }
      $totalInput.val(lineTotalwithTax.toFixed(2)); // Keep raw value for hidden input

      // Accumulate overall totals
      const lineTax = lineTotal * (taxRate / 100) + extraTax - discountTax;
      subtotal += lineTotal;
      totalTax += lineTax;

      if (taxRateVal !== null && taxRateVal !== "" && taxRateVal !== undefined) {
        if (!taxBreakdown[taxName]) taxBreakdown[taxName] = { tax: 0, basis: 0 };
        taxBreakdown[taxName].tax += lineTax;
        taxBreakdown[taxName].basis += lineTotal;
      }
    });


    // --- Global price adjustments ---
    // --- Global price adjustments ---
    $('.discount-item').each(function () {
      const $row = $(this);

      const type = ($row.find('select.price-adjustment-unit').val() || "").trim();
      const isPercent = $row.find('select.unit-type').val() === "true";
      const qty = parseCurrency($row.find('.amount').val());

      let value = isPercent ? subtotal * (qty / 100) : qty;

      // Format global adjustment totals
      if (type === "discount") {
        discountAmount += value;
        $row.find('.total').text(`-${formatCurrency(value)}`);
      } else if (type === "charge") {
        chargeAmount += value;
        $row.find('.total').text(`+${formatCurrency(value)}`);
      } else if (type === "fixedtax") {
        fixedTax += value;
        if (!taxBreakdown["Fixed Tax"]) taxBreakdown["Fixed Tax"] = { tax: 0, basis: subtotal };
        taxBreakdown["Fixed Tax"].tax += value;
        $row.find('.total').text(`+${formatCurrency(value)}`);
      } else {
        // fallback for unexpected values & ensure we always format
        $row.find('.total').text(formatCurrency(value));
      }
    });

    const adjustedSubtotal = subtotal - discountAmount + chargeAmount;
    const grandTotal = adjustedSubtotal + totalTax + fixedTax;

    const totalsJson = {
      subtotal: adjustedSubtotal.toFixed(2),
      tax: (totalTax + fixedTax).toFixed(2),
      grand_total: grandTotal.toFixed(2),
      tax_breakdown: taxBreakdown
    };

    $('#total_amount_json').val(JSON.stringify(totalsJson));
    $('.subtotal-amount').text(formatCurrency(totalsJson.subtotal));
    $('.total-tax-amount').text(formatCurrency(totalsJson.tax));
    $('.grand-total-amount').text(formatCurrency(totalsJson.grand_total));

    const $breakdownContainer = $('#tax-breakdown-container');
    if ($breakdownContainer.length) {
      $breakdownContainer.empty();
      const taxKeys = Object.keys(taxBreakdown);
      const currency = $('.currency_type').first().text();

      if (taxKeys.length > 0) {
        taxKeys.forEach(name => {
          const data = taxBreakdown[name];
          $breakdownContainer.append(`<p class="mb-1">${name} <i>of ${formatCurrency(data.basis)} ${currency}</i> <span class="ms-4 fw-bold">${formatCurrency(data.tax)}</span></p>`);
        });
      }

      if (taxKeys.length > 0 || totalTax + fixedTax !== 0) {
        $('#total-taxes-row').show();
      } else {
        $('#total-taxes-row').hide();
      }
    }
  }

  $(document).on(
    'input.invoice_form change.invoice_form',
    '#line-items .line-item input, #line-items .line-item select, #line-items .discount-item input, #line-items .discount-item select, .optional-field-row input, .optional-field-row select',
    function () {
      recalculateTotals();
    }
  );


  // Auto-format price fields on blur
  $(document).on('blur', '.price, .amount, .optional-field-row input[placeholder="Amount"]', function () {
    $(this).val(formatCurrency($(this).val()));
  });

  /*
  $('#recipient_company_id').on('change', function () {
    const selected = $(this).find('option:selected');
  
    $('#company_name').text(selected.data('name') || '');
    $('#company_address').text(selected.data('address') || '');
    $('#company_country').text("Philippines");
    $('#company_number').text('Company ' + (selected.data('company-id-type') || '') + ' number : ' + (selected.data('company-id-number') || '-'));
    $('#company_tax_number').text('Tax ' + (selected.data('tax-id-type') || '') + ' number : ' + (selected.data('tax-id-number') || '-'));
  
    $('#recipient-preview').removeClass('d-none');
    $('#recipient_company_id').addClass('d-none');
  });
  
  $('#change-recipient').on('click', function (e) {
    e.preventDefault();
    $('#recipient-preview').addClass('d-none');
    $('#recipient_company_id').removeClass('d-none');
    $('#recipient_company_id').val('');
  });
  */

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
    const inputTypes = ['text', 'date', 'number', 'select', 'checkbox', 'radio', 'textarea'];

    Object.entries(invoiceInfo).forEach(([fullKey, value]) => {
      if (!value || value.trim() === "") return;

      const parts = fullKey.split('.');
      const groupKey = parts[0];
      const colsMatch = fullKey.match(/\.(\d+)$/);
      const cols = colsMatch ? colsMatch[1] : '12';

      // 👇 get the second-to-the-last part (field type)
      let rawType = parts[parts.length - 2] || 'text';

      // Handle select(field1,field2)
      let type = 'text';
      let selectOptions = null;

      const selectMatch = rawType.match(/^select\(([^)]+)\)$/i);
      if (selectMatch) {
        type = "select";
        selectOptions = selectMatch[1].split(',').map(opt => opt.trim());
      } else if (inputTypes.includes(rawType.toLowerCase())) {
        type = rawType.toLowerCase();
      }

      // Label = second part OR fallback
      let label = parts.length > 2 ? parts[1] : groupKey;

      label = label
        .replace(/_/g, ' ')
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
        .replace(/\b\w/g, l => l.toUpperCase());

      if (groupKey.toLowerCase() === 'fileid' && parts.length === 2) {
        label = 'File';
      }

      if (!groups[groupKey]) {
        groups[groupKey] = [];
      }

      groups[groupKey].push({
        fullKey,
        label,
        type,
        cols,
        value,
        selectOptions
      });
    });

    // Render
    Object.entries(groups).forEach(([groupKey, fields]) => {
      if ($container.find(`[data-optional-group="${groupKey}"]`).length > 0) return;

      let groupHtml = `<div class="mb-3 position-relative border rounded p-3 pt-3 optional-group" data-optional-group="${groupKey}">`;
      groupHtml += `<button type="button" class="btn btn-sm btn-outline-danger rounded position-absolute top-0 end-0 m-2 remove-group">×</button>`;

      if (fields.length === 1) {
        const f = fields[0];
        groupHtml += `<div class="row"><div class="col-md-${f.cols} mb-3">`;
        groupHtml += `<h6>${f.label}</h6>`;

        if (f.type === "select" && f.selectOptions) {
          groupHtml += `<select class="form-control optional-input" data-field-name="${f.fullKey}">`;
          f.selectOptions.forEach(opt => {
            const selected = (opt.toLowerCase() === f.value.toLowerCase()) ? "selected" : "";
            groupHtml += `<option value="${opt}" ${selected}>${opt.charAt(0).toUpperCase() + opt.slice(1)}</option>`;
          });
          groupHtml += `</select>`;
        } else {
          groupHtml += `<input type="${f.type}" class="form-control optional-input" data-field-name="${f.fullKey}" value="${f.value}">`;
        }

        groupHtml += `</div></div>`;
      } else {
        const cleanGroupName = groupKey
          .replace(/_/g, ' ')
          .replace(/([a-z])([A-Z])/g, '$1 $2')
          .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
          .replace(/\b\w/g, l => l.toUpperCase())
          .replace(/Id\b/, 'ID');

        groupHtml += `<h6>${cleanGroupName}</h6><div class="row">`;

        fields.forEach(field => {
          groupHtml += `<div class="col-md-${field.cols} mb-1">`;
          groupHtml += `<label class="form-label">${field.label}</label>`;

          if (field.type === "select" && field.selectOptions) {
            groupHtml += `<select class="form-control optional-input" data-field-name="${field.fullKey}">`;
            field.selectOptions.forEach(opt => {
              const selected = (opt.toLowerCase() === field.value.toLowerCase()) ? "selected" : "";
              groupHtml += `<option value="${opt}" ${selected}>${opt.charAt(0).toUpperCase() + opt.slice(1)}</option>`;
            });
            groupHtml += `</select>`;
          } else {
            groupHtml += `<input type="${field.type}" class="form-control optional-input" data-field-name="${field.fullKey}" value="${field.value}">`;
          }

          groupHtml += `</div>`;
        });
        groupHtml += `</div>`;
      }

      groupHtml += `</div>`;
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

    if (!Array.isArray(data) || data.length === 0) return;

    $lineItems.empty();

    // Update global lineIndex to avoid conflicts with new lines
    lineIndex = data.length;

    data.forEach((item, i) => {
      const $html = $(getLineItemHTML(i, item.tax));
      $lineItems.append($html);

      $html.find('.item-id').val(item.item_id);
      $html.find('.description').val(item.description);
      $html.find('.quantity').val(item.quantity);
      const $unitSelect = $html.find('.unit');
      $unitSelect.html(buildUnitOptions(item.unit));
      $unitSelect.val(item.unit);
      $html.find('.price').val(formatCurrency(item.price));

      if (item.optional_fields) { $html.find('.toggle-dropdown').text('–'); }

      if (item.optional_fields) {
        Object.entries(item.optional_fields).forEach(([groupKey, fields]) => {
          const $optionalRow = $(`
              <tr class="optional-field-row bg-light" data-optional-group="${groupKey}" data-line-index="${i}">
                <td></td><td></td>
              </tr>
            `);

          const fieldsToRender = Object.entries(fields).map(([rawKey, val]) => {
              let type = "text", value = "", options = [];

              if (typeof val === "object") {
                value = val.value || "";
                type = val.type || "text";
              } else {
                value = val;
              }

              const label = rawKey.split('.')[0].replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());

              if (rawKey.includes('select(')) {
                const match = rawKey.match(/select\((.*?)\)/);
                const optionSource = match?.[1]?.trim() || '';
                type = "select";

                // ✅ Handle external constants
                if (optionSource === "DISCOUNT_OPTIONS") {
                  options = DISCOUNT_OPTIONS;
                } else if (optionSource === "COUNTRY_OPTIONS") {
                  options = COUNTRY_OPTIONS;
                } else {
                  options = optionSource.split(',').map(opt => opt.trim());
                }
              }

              return { name: rawKey, label, type, value, options };
            });

          let newRowHtml = "";

          const isDiscountOrCharge = Object.keys(fields).some(k =>
            k.toLowerCase().includes("discount") || k.toLowerCase().includes("charge")
          );

          if (isDiscountOrCharge) {
            const orderedKeys = ["", "discount_type", "charge_type", "edit_type", "amount", "quantity", "unit", "total"];
            const orderedFields = [];
            orderedKeys.forEach(key => {
              const found = fieldsToRender.find(f =>
                f.name.toLowerCase().includes(key) && key !== ""
              );
              if (found) orderedFields.push(found);
            });

            orderedFields.forEach(field => {
              let inputHtml = "";
              const inputName = `invoice[line_items_attributes][${i}][optional_fields][${groupKey}.${field.name}]`;

              if (field.type === "select") {
                const optionsHtml = field.options.map(opt =>
                  `<option value="${opt}" ${opt.toLowerCase() === (field.value || '').toLowerCase() ? "selected" : ""}>${opt}</option>`
                ).join("");
                inputHtml = `
                    <select name="${inputName}" class="form-select form-select-sm">
                      <option value="" disabled ${!field.value ? "selected" : ""}>${field.label}</option>
                      ${optionsHtml}
                    </select>
                  `;
              } else if (field.type === "date") {
                inputHtml = `
                    <input 
                      type="text"
                      name="${inputName}"
                      class="form-control form-control-sm flatpickr-date"
                      placeholder="${field.label}"
                      value="${field.value || ''}"
                      readonly
                      autocomplete="off"
                    >
                  `;
              } else if (field.name.toLowerCase().includes("total")) {
                inputHtml = `
                    <span class="form-control-plaintext text-end optional-total" data-total-type="${groupKey}" data-line-index="${i}">0.00</span>
                    <input type="hidden" name="${inputName}" class="form-control optional-total-input" value="${field.value}">
                  `;
              } else {
                inputHtml = `
                    <input 
                      type="${field.type}"
                      name="${inputName}"
                      class="form-control form-control-sm"
                      placeholder="${field.label}"
                      value="${field.value || ''}"
                    >
                  `;
              }

              newRowHtml += `<td>${inputHtml}</td>`;
            });

            if (!orderedFields.some(f => f.name.toLowerCase().includes("total"))) {
              newRowHtml += `
                  <td>
                    <span class="form-control-plaintext text-end optional-total" data-total-type="${groupKey}" data-line-index="${i}">0.00</span>
                    <input type="hidden" name="invoice[line_items_attributes][${i}][optional_fields][${groupKey}.total]" class="form-control optional-total-input" value="">
                  </td>
                `;
            }

          } else {
            // Default layout for non-discount/charge optional fields
            fieldsToRender.forEach(field => {
              let inputHtml = "";
              const inputName = `invoice[line_items_attributes][${i}][optional_fields][${groupKey}.${field.name}]`;

              if (field.type === "select") {
                const optionsHtml = field.options.map(opt =>
                  `<option value="${opt}" ${opt === field.value ? "selected" : ""}>${opt}</option>`
                ).join("");
                inputHtml = `
                    <select name="${inputName}" class="form-select form-select-sm">
                      <option value="" disabled ${!field.value ? "selected" : ""}>${field.label}</option>
                      ${optionsHtml}
                    </select>
                  `;
              } else if (field.type === "date") {
                inputHtml = `
                    <input 
                      type="text"
                      name="${inputName}"
                      class="form-control form-control-sm flatpickr-date"
                      placeholder="${field.label}"
                      value="${field.value || ''}"
                      readonly
                      autocomplete="off"
                    >
                  `;
              } else if (field.name.toLowerCase().includes("total")) {
                inputHtml = `
                    <span class="form-control-plaintext text-end optional-total" data-total-type="${groupKey}" data-line-index="${i}">0.00</span>
                    <input type="hidden" name="${inputName}" class="form-control optional-total-input" value="${field.value}">
                  `;
              } else {
                inputHtml = `
                    <input 
                      type="${field.type}"
                      name="${inputName}"
                      class="form-control form-control-sm"
                      placeholder="${field.label}"
                      value="${field.value || ''}"
                    >
                  `;
              }

              newRowHtml += `<td>${inputHtml}</td>`;
            });
          }

          // Fill up remaining columns if needed
          const totalCols = 7;
          if (fieldsToRender.length < totalCols) {
            const emptyCols = totalCols - fieldsToRender.length - 1;
            for (let i = 0; i < emptyCols; i++) {
              newRowHtml += `<td></td>`;
            }
          }

          newRowHtml += `
              <td>
                <button type="button" class="btn btn-sm btn-outline-danger remove-line">-</button>
              </td>
            `;

          $optionalRow.append(newRowHtml);
          $lineItems.find(`.dropdown_per_line[data-line-index="${i}"]`).before($optionalRow);
        });
      }

      if (window.invoiceInitTimeout) clearTimeout(window.invoiceInitTimeout);
      window.invoiceInitTimeout = setTimeout(() => {
        recalculateTotals();
        updateRemoveButtons();
      }, 100);
    });

    // Initialize Flatpickr for date fields
    function initFlatpickrs() {
      $('.flatpickr-date').each(function () {
        const fp = flatpickr(this, {
          dateFormat: "Y-m-d",
          clickOpens: false,
          allowInput: false,
        });
        $(this).on('click', function () { fp.open(); });
      });
    }

    initFlatpickrs();

    $(document).on('DOMNodeInserted', '.flatpickr-date', function () {
      initFlatpickrs();
    });

    $(document).on("click", ".remove-group", function () {
      $(this).closest('tr.optional-field-row').remove();
      recalculateTotals();
    });
  });


  // Render payment terms from JSON
  $(function () {
    const $input = $('#payment_terms_json_edit');
    let raw = $input.val().trim();
    let data = {};

    // If value is empty, try reading from name attribute
    if (!raw) {
      const nameAttr = $input.attr('name') || "";
      const match = nameAttr.match(/\[(\{.*\})\]$/); // capture JSON inside []
      raw = match ? match[1] : "";
    }

    if (raw) {
      try {
        data = JSON.parse(raw);
      } catch (e) {
        console.error("Invalid JSON in payment_terms_json:", e.message, raw);
      }
    } else {
      console.warn("payment_terms_json_edit JSON is empty, using default {}");
    }

    renderPaymentTerms(data);
  });

  function renderPaymentTerms(data) {
    const $container = $('#payment_terms_parent_div');
    if ($container.length === 0) {
      const isCreditNote = document.getElementById('invoice_invoice_category')?.value === 'credit_note';
      if (!isCreditNote) {
        console.warn('#payment_terms_parent_div not found');
      }
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
      const unit = adjustment.type ?? "discount";
      const unitType = adjustment.unit_type === "%" ? "true" : "false";
      const description = adjustment.description ?? "";
      const descriptionEdit = adjustment.description_edit ?? "";
      const totalFormatted = `${unitType === "true" ? "+" : "+"}${formatCurrency(amount)}`;

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
              <input type="text" class="form-control amount" value="${formatCurrency(amount)}" data-field="amount">
            </td>
            <td class="align-top">
              <select class="form-select unit-type" data-field="unit_type">
                <option value="false"${unitType === "false" ? " selected" : ""}><span class="currency_type">PHP</span></option>
                <option value="true"${unitType === "true" ? " selected" : ""}>%</option>
              </select>
            </td>
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

    let $lastRow = $(".line-item, .dropdown_per_line").last();

    priceAdjustments.forEach(adjustment => {
      const html = renderAdjustmentRow(adjustment);
      $lastRow.after(html);
      $lastRow = $lastRow.next();
    });
  });

  // Check if form has hidden inputs with space-separated key-value pairs
  $('[data-field-type="invoice_form_fields"]').each(function () {
    let val = $(this).val();

    try {
      JSON.parse(val);
    } catch (err) {
      let obj = {};
      let parts = val.trim().split(/\s+/);

      for (let i = 0; i < parts.length; i += 2) {
        let key = parts[i];
        let value = parts[i + 1] || "";
        obj[key] = value;
      }

      $(this).val(JSON.stringify(obj));
    }
  });

  function updateCurrencyFields() {
    let selectedCurrency = $("#invoice_currency").val();

    if (selectedCurrency) {
      $(".currency_type").text(selectedCurrency);

      $("select[name*='discount.unit.select(php,%).2'], select[name*='charge.unit.select(php,%).2']").each(function () {
        const currentValue = $(this).val();
        $(this).empty()
          .append(`<option value="${selectedCurrency}">${selectedCurrency}</option>`)
          .append(`<option value="%">%</option>`);
        if (currentValue === "%" || currentValue === selectedCurrency) {
          $(this).val(currentValue);
        }
      });
    }
  }

  $(document).on("change", "#invoice_currency", function () {
    updateCurrencyFields();
  });

  // DataTransfer to manage file additions/removals
  const attachmentDataTransfer = new DataTransfer();

  function updateNewAttachmentPreviews() {
    const $container = $('#new_attachments_preview');
    $container.empty();
    const files = Array.from(attachmentDataTransfer.files);

    for (let i = 0; i < files.length; i += 2) {
      let rowHtml = '<div class="row no-break">';
      for (let j = i; j < i + 2 && j < files.length; j++) {
        const file = files[j];
        let contentHtml = '';
        if (file.type.startsWith('image/')) {
          const objectUrl = URL.createObjectURL(file);
          contentHtml = `<img src="${objectUrl}" class="img-fluid rounded mb-2" style="max-height: 150px; object-fit: contain;">`;
        } else {
          contentHtml = `<i class="bi bi-file-earmark-text fs-1 text-muted"></i>`;
        }

        rowHtml += `
             <div class="col-6 mb-3">
               <div class="card h-100 d-flex flex-column">
                 <div class="card-body text-center flex-grow-1 d-flex align-items-center justify-content-center">
                   ${contentHtml}
                 </div>
                 <div class="p-2 text-center mt-auto border-top">
                   <small class="d-block text-truncate w-100 mb-2 fw-bold" title="${file.name}">${file.name}</small>
                   <button type="button" class="btn btn-sm btn-outline-danger remove-new-attachment w-100" data-index="${j}">
                     <i class="bi bi-trash"></i> Remove
                   </button>
                 </div>
               </div>
             </div>
           `;
      }
      rowHtml += '</div>';
      $container.append(rowHtml);
    }
  }


  $(document).on("click", ".remove-new-attachment", function () {
    const index = $(this).data('index');
    const dt = new DataTransfer();

    Array.from(attachmentDataTransfer.files).forEach((file, i) => {
      if (i !== index) {
        dt.items.add(file);
      }
    });

    attachmentDataTransfer.items.clear();
    Array.from(dt.files).forEach(file => attachmentDataTransfer.items.add(file));

    // Update input files
    $('#attachments')[0].files = attachmentDataTransfer.files;
    updateNewAttachmentPreviews();
  });

  $(document).on("change", "#attachments", function () {
    const allowedTypes = ["image/jpeg", "image/png", "image/gif", "application/pdf"];
    const maxSize = 10 * 1024 * 1024;
    const $errorDiv = $("#fileError");

    const $saveDraftBtn = $("input[value='Save As Draft']");
    const $sendBtn = $("#send_invoice_btn");

    $errorDiv.text("");
    let hasError = false;

    // Clear previous files and reset DataTransfer to only contain newly selected files
    attachmentDataTransfer.items.clear();

    // Add newly selected files to our DataTransfer object
    $.each(this.files, function (_, file) {
      if (!allowedTypes.includes(file.type)) {
        $errorDiv.text(file.name + " is not a valid file. Only JPEG, PNG, GIF, and PDF are allowed.");
        hasError = true;
        return true; // continue
      }

      if (file.size > maxSize) {
        $errorDiv.text(file.name + " exceeds the 10MB size limit.");
        hasError = true;
        return true; // continue
      }

      // Add to DataTransfer
      attachmentDataTransfer.items.add(file);
    });

    // Set the input files to the DataTransfer files
    this.files = attachmentDataTransfer.files;

    if (hasError) {
    }

    if (attachmentDataTransfer.files.length > 0 && !hasError) {
      $saveDraftBtn.prop("disabled", false);
      $sendBtn.prop("disabled", false);
    } else if (hasError) {
      $saveDraftBtn.prop("disabled", true);
      $sendBtn.prop("disabled", true);
    }

    updateNewAttachmentPreviews();
  });

  $(document).on("click", "#send_invoice_btn, #view_invoice_send_btn", function (e) {
    // Check for unselected tax in line items
    let hasUnselectedTax = false;
    $('.tax').each(function () {
      if ($(this).val() === "" || $(this).val() === null) {
        hasUnselectedTax = true;
        return false; // break out of each loop
      }
    });

    if (hasUnselectedTax) {
      e.preventDefault();
      showFlashMessage("Please select a tax rate for all line items before proceeding.", "danger");
      return;
    }

    // Skip payment terms validation for Credit Notes and Quotes
    const category = $('input[name="invoice[invoice_category]"]').val();
    if (category === 'credit_note' || category === 'quote') return;

    let inputId = this.id === "send_invoice_btn" ? "#payment_terms_json" : (this.id === "view_invoice_send_btn" ? "#view_invoicepayment_terms_json" : "#payment_terms_json_edit");
    if (!$(inputId).val() || $(inputId).val() === "[]" || $(inputId).val() === "{}") {
      e.preventDefault();
      showFlashMessage("Please add payment terms before sending it to recipient.", "danger");
    }
  });

  // Validate tax selection on form submission
  $(document).on("submit", "form", function (e) {
    const $form = $(this);

    // Validate credit note number for credit notes
    const $invoiceCategoryField = $form.find('input[name="invoice[invoice_category]"]');
    if ($invoiceCategoryField.length > 0) {
      const category = $invoiceCategoryField.val();
      if (category === 'credit_note') {
        const creditNoteNumber = $form.find('input[name="invoice[invoice_number]"]').val();
        if (!creditNoteNumber || creditNoteNumber.trim() === '') {
          e.preventDefault();
          showFlashMessage("Please enter a credit note number before saving.", "danger");
          const $numberField = $form.find('input[name="invoice[invoice_number]"]');
          if ($numberField.length) {
            $numberField[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
            $numberField.focus();
          }
          return false;
        }
      }
    }

    let hasUnselectedTax = false;
    $('.tax').each(function () {
      if ($(this).val() === "" || $(this).val() === null) {
        hasUnselectedTax = true;
        return false; // break out of each loop
      }
    });

    if (hasUnselectedTax) {
      e.preventDefault();
      showFlashMessage("Please select a tax rate for all line items before saving.", "danger");
      // Scroll to the first unselected tax dropdown
      const firstUnselected = $('.tax').filter(function () { return $(this).val() === "" || $(this).val() === null; }).first();
      if (firstUnselected.length) {
        firstUnselected[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
        firstUnselected.focus();
      }
      return false;
    }
  });

  // Invoice Preview Modal
  (function () {
    const $previewBtn = $('#preview-invoice-btn');
    const modalEl = $('#invoicePreviewModal')[0];

    if (!$previewBtn.length || !modalEl) return;

    // Remove any lingering backdrops from previous instances
    $('.modal-backdrop').remove();
    $('body').removeClass('modal-open').css('overflow', '').css('padding-right', '');

    const modal = bootstrap.Modal.getOrCreateInstance(modalEl);
    const $previewCard = $('#invoicePreviewCard');

    $previewBtn.off('click.invoice_preview').on('click.invoice_preview', function () {
      const $form = $('form');
      const formData = new FormData($form[0]);

      // If it's an edit, add the ID to the form data
      const invoiceId = window.location.pathname.split('/')[2];
      if (window.location.pathname.includes('/edit') && invoiceId) {
        formData.append('id', invoiceId);
      }

      $previewCard.html('<div class="text-center p-5"><div class="spinner-border text-primary" role="status"></div><p class="mt-2">Loading preview...</p></div>');
      modal.show();

      $.ajax({
        url: '/invoices/preview',
        method: 'POST',
        data: formData,
        processData: false,
        contentType: false,
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
        success: function (data) {
          $previewCard.html(data);

          const $modalNewAttachments = $('#modal_new_attachments_preview');
          if ($modalNewAttachments.length && attachmentDataTransfer.files.length > 0) {
            $('#attachments-section').removeClass('d-none');
            $('#no-attachments-msg').addClass('d-none');

            const files = Array.from(attachmentDataTransfer.files);
            for (let i = 0; i < files.length; i += 2) {
              let rowHtml = '<div class="row no-break">';
              for (let j = i; j < i + 2 && j < files.length; j++) {
                const file = files[j];
                let contentHtml = '';
                if (file.type.startsWith('image/')) {
                  const objectUrl = URL.createObjectURL(file);
                  contentHtml = `<img src="${objectUrl}" class="img-fluid rounded mb-2" style="max-height: 300px; object-fit: contain;">`;
                } else if (file.type === "application/pdf") {
                  const objectUrl = URL.createObjectURL(file);
                  contentHtml = `<embed src="${objectUrl}" type="application/pdf" class="w-100 mb-2" style="height: 200px;" />`;
                } else {
                  contentHtml = `<i class="bi bi-file-earmark-text fs-1 text-muted"></i>`;
                }

                rowHtml += `
                          <div class="col-6 mb-4 d-flex">
                              <div class="card h-100 w-100 d-flex flex-column mt-2">
                                  <div class="card-body text-center flex-grow-1 d-flex align-items-center justify-content-center">
                                      ${contentHtml}
                                  </div>
                                  <div class="text-center mt-auto bg-light py-2">
                                      <div class="d-flex flex-column align-items-center px-2">
                                          <span class="mb-2 text-truncate small fw-bold" style="max-width: 100%;" title="${file.name}">
                                              ${file.name}
                                          </span>
                                          ${getThemeAwareBadgeClass('New Attachment', 'primary')}
                                      </div>
                                  </div>
                              </div>
                          </div>
                      `;
              }
              rowHtml += '</div>';
              $modalNewAttachments.append(rowHtml);
            }
          }
        },
        error: function () {
          $previewCard.html('<div class="alert alert-danger">Failed to load preview. Please ensure all required fields are filled.</div>');
        }
      });
    });
  })();


  // -------------------------------------------------------------------------
  // TAX MANAGEMENT LOGIC
  // -------------------------------------------------------------------------

  // 1. Open Modal on Custom Selection
  $(document).on('change.invoice_form', '.tax', function () {
    if ($(this).val() === 'custom') {
      const modalEl = document.getElementById('taxManagementModal');
      if (modalEl) {
        const bs = (typeof bootstrap !== 'undefined') ? bootstrap : (window.bootstrap || null);
        if (bs && bs.Modal) {
          const modal = bs.Modal.getOrCreateInstance(modalEl);
          modal.show();
        } else {
          console.error("Bootstrap is not defined");
          alert("Unable to open settings. Please refresh the page.");
        }
      }
      $(this).val(''); // Reset to avoid sticking on "custom"
    }
  });

  // 2. Populate Modal List
  const $modalEl = $('#taxManagementModal');
  if ($modalEl.length) {
    $modalEl.off('shown.bs.modal').on('shown.bs.modal', function () {
      renderTaxList();
      resetTaxForm();
    });
  }

  let editingTaxId = null;

  function renderTaxList() {
    const $list = $('#tax-rate-list');
    $list.empty();

    if (!window.TAX_RATES) return;

    window.TAX_RATES.forEach(tax => {
      const isSystem = !tax.custom;
      const buttons = isSystem ? '' : `
        <div class="float-end">
          <button class="btn btn-sm btn-outline-primary edit-tax-btn me-1" data-id="${tax.id}" style="font-size: 0.7rem;">Edit</button>
          <button class="btn btn-sm btn-outline-danger delete-tax-btn" data-id="${tax.id}" style="font-size: 0.7rem;">Delete</button>
        </div>
      `;

      const item = `
            <li class="list-group-item">
              <span class="fw-bold">${tax.name}</span> (${tax.rate}%)
              ${buttons}
            </li>
          `;
      $list.append(item);
    });
  }

  function resetTaxForm() {
    editingTaxId = null;
    $('#new-tax-name').val('');
    $('#new-tax-rate').val('');
    $('#add-tax-btn').text('Add');
    $('#tax-form-title').text('Add Custom Tax Rate');
    $('#tax-error').text('');
    $('.cancel-tax-btn').remove();
  }

  // 3. Add/Update Tax Rate
  $('#add-tax-btn').off('click').on('click', function (e) {
    e.preventDefault();
    const name = $('#new-tax-name').val().trim();
    const rate = $('#new-tax-rate').val();

    if (!name || !rate) {
      $('#tax-error').text('Name and Rate are required.');
      return;
    }

    const rateNum = parseFloat(rate);
    if (isNaN(rateNum) || rateNum < -100 || rateNum > 100) {
      $('#tax-error').text('Rate must be between -100 and 100.');
      return;
    }

    const $btn = $(this);
    const isEditing = editingTaxId !== null;
    $btn.prop('disabled', true).text(isEditing ? 'Updating...' : 'Adding...');

    const url = isEditing ? `/tax_rates/${editingTaxId}` : '/tax_rates';
    const method = isEditing ? 'PATCH' : 'POST';

    $.ajax({
      url: url,
      method: method,
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      data: { tax_rate: { name: name, rate: rate } },
      success: function (response) {
        if (response.success) {
          const updatedTax = {
            id: response.tax_rate.id,
            name: response.tax_rate.name,
            rate: response.tax_rate.rate,
            custom: true
          };

          if (isEditing) {
            const index = window.TAX_RATES.findIndex(t => t.id == editingTaxId);
            if (index !== -1) window.TAX_RATES[index] = updatedTax;
            showFlashMessage("Tax rate updated successfully.", "success");
            editingTaxId = null;
          } else {
            window.TAX_RATES.push(updatedTax);
            showFlashMessage("Tax rate added successfully.", "success");
          }

          refreshAllTaxSelects(updatedTax.rate);
          renderTaxList();

          resetTaxForm();

          // If not complex, just hide modal or let user stay
          // Requirement: Display success message and refresh list.
          // For now we stay in the modal and show the refreshed list.
        }
      },
      error: function (xhr) {
        const err = xhr.responseJSON?.errors?.join(', ') || 'Failed to process tax rate.';
        $('#tax-error').text(err);
      },
      complete: function () {
        $btn.prop('disabled', false).text(editingTaxId !== null ? 'Update' : 'Add');
      }
    });
  });

  // 3.5 Edit Tax Rate Button Click
  $(document).on('click.invoice_form', '.edit-tax-btn', function () {
    const id = $(this).data('id');
    const tax = window.TAX_RATES.find(t => t.id == id);
    if (!tax) return;

    editingTaxId = id;
    $('#new-tax-name').val(tax.name);
    $('#new-tax-rate').val(tax.rate);
    $('#add-tax-btn').text('Update');
    $('#tax-form-title').text('Edit Tax Rate');
    $('#tax-error').text('');

    // Add Cancel Button if not already there
    if ($('.cancel-tax-btn').length === 0) {
      $('#add-tax-btn').after('<button type="button" class="btn btn-outline-secondary cancel-tax-btn">Cancel Edit</button>');
    }

    // Smooth scroll to form
    const $form = $('#new-tax-name').closest('.row');
    $form[0].scrollIntoView({ behavior: 'smooth' });
  });

  $(document).on('click.invoice_form', '.cancel-tax-btn', function () {
    resetTaxForm();
  });

  // 4. Delete Tax Rate
  $(document).on('click.invoice_form', '.delete-tax-btn', function () {
    if (!confirm('Are you sure you want to delete this custom tax rate?')) return;

    const id = $(this).data('id');
    const $btn = $(this);
    $btn.prop('disabled', true).text('...');

    $.ajax({
      url: `/tax_rates/${id}`,
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      success: function (response) {
        if (response.success) {
          window.TAX_RATES = window.TAX_RATES.filter(t => t.id != id);
          renderTaxList();
          refreshAllTaxSelects();
        }
      },
      error: function () {
        alert('Failed to delete tax rate.');
        $btn.prop('disabled', false).text('Delete');
      }
    });
  });

  function refreshAllTaxSelects(newRateToSelect) {
    $('.tax').each(function () {
      const $select = $(this);
      const currentVal = $select.val();

      // Rebuild options
      const targetVal = (currentVal && currentVal !== 'custom') ? currentVal : newRateToSelect;

      const newHtml = buildTaxOptions(targetVal);
      $select.html(newHtml);
    });
    recalculateTotals();
  }
};

// Listen for theme changes and update dynamically generated badges
document.addEventListener('theme:changed', function(e) {
    // Update "New Attachment" badges (both subtle and solid)
    const newAttachmentBadges = document.querySelectorAll('.badge.bg-primary-subtle, .badge.bg-primary');
    newAttachmentBadges.forEach(badge => {
        if (e.detail.theme === 'dark') {
            // Convert to solid colors in dark mode
            if (badge.classList.contains('bg-primary-subtle')) {
                badge.classList.remove('bg-primary-subtle', 'text-primary');
                badge.classList.add('bg-primary', 'text-white');
            }
        } else {
            // Convert back to subtle colors in light mode
            if (badge.classList.contains('bg-primary')) {
                badge.classList.remove('bg-primary', 'text-white');
                badge.classList.add('bg-primary-subtle', 'text-primary');
            }
        }
    });
});

document.addEventListener("turbo:load", initInvoiceForm);
initInvoiceForm();
