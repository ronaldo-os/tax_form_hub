require "test_helper"

class LabelCapitalizationStandardizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "label_cap_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(
      name: "Apex Global Solutions",
      user: @user
    )
    @user.update!(company: @company)
  end

  test "company profile page renders consistent Title Case labels and select prompts" do
    sign_in @user
    get companies_path
    assert_response :success

    form_labels = css_select("label.form-label").map { |el| el.text.strip }

    expected_labels = [
      "Company Name",
      "Website",
      "Industry",
      "Company Ownership",
      "Company Address",
      "Country/Region",
      "Phone",
      "Company Description",
      "Company Size",
      "Share Capital",
      "Registration Address",
      "Company Email Address",
      "Company ID Type",
      "Tax ID Type",
      "GLN",
      "Company ID Number",
      "Tax ID Number",
      "Internal Identifier"
    ]

    expected_labels.each do |label_text|
      assert_includes form_labels, label_text, "Expected Company Profile page to include label '#{label_text}'"
    end

    # Legacy sentence-case labels must not be present
    refute_includes form_labels, "Share capital"
    refute_includes form_labels, "Registration address"

    # Select prompts and blank options use Title Case
    option_texts = css_select("select option").map { |el| el.text.strip }
    assert_includes option_texts, "Select Industry"
    assert_includes option_texts, "Select Ownership"
    assert_includes option_texts, "Select Country"
    assert_includes option_texts, "Select Company Size"
    assert_includes option_texts, "Select Company ID Type"
    assert_includes option_texts, "Select Tax ID Type"

    refute_includes option_texts, "Select country"
    refute_includes option_texts, "Select company ID type"
    refute_includes option_texts, "Select tax ID type"
  end

  test "company model industry and ownership options use Title Case display labels while preserving database values" do
    industry_labels = Company::INDUSTRIES.map(&:first)
    industry_values = Company::INDUSTRIES.map { |entry| entry[1] }

    assert_includes industry_labels, "Animal Care"
    assert_includes industry_labels, "Government and Public Services"
    assert_includes industry_labels, "Not for Profit"
    assert_includes industry_labels, "Research (Non-Academic)"
    refute_includes industry_labels, "Animal care"
    refute_includes industry_labels, "Government and public services"
    refute_includes industry_labels, "Not for profit"
    refute_includes industry_labels, "Research (non-academic)"

    # Values remain untouched for database backward compatibility
    assert_includes industry_values, "ANIMAL"
    assert_includes industry_values, "GOVERNMENT"
    assert_includes industry_values, "NOT_FOR_PROFIT"
    assert_includes industry_values, "RESEARCH"

    ownership_labels = Company::OWNERSHIPS.map(&:first)
    ownership_values = Company::OWNERSHIPS.map { |entry| entry[1] }

    assert_includes ownership_labels, "Sole Proprietorship"
    assert_includes ownership_labels, "General Partnership"
    assert_includes ownership_labels, "Limited Partnership"
    assert_includes ownership_labels, "Association/Non-Profit/NGO"
    assert_includes ownership_labels, "Private Limited Company"
    assert_includes ownership_labels, "Public Limited Company"
    assert_includes ownership_labels, "Investment Company with Variable Capital"
    assert_includes ownership_labels, "Government Owned Corporation"
    assert_includes ownership_labels, "Independent Contractor"

    refute_includes ownership_labels, "Sole proprietorship"
    refute_includes ownership_labels, "Private limited company"
    refute_includes ownership_labels, "Independent contractor"

    assert_includes ownership_values, "SOLE"
    assert_includes ownership_values, "PRIVATE_LIMITED"
    assert_includes ownership_values, "INDEPENDENT_CONTRACTOR"
  end

  test "companies javascript prevents blank prompt option from overwriting dynamic ID labels" do
    companies_js = File.read(Rails.root.join("app/javascript/companies.js"))
    assert_includes companies_js, "var selectedVal = $select.val();"
    assert_includes companies_js, "if (selectedVal && selectedText)"
  end

  test "locations page modal renders standardized Title Case field labels" do
    sign_in @user
    get locations_path
    assert_response :success

    location_labels = css_select("#locationModal label.form-label").map { |el| el.text.strip }

    expected_location_labels = [
      "Location Name",
      "Country",
      "Company Name",
      "Tax Number",
      "Post Box",
      "Street Name",
      "Building",
      "Additional Street Name",
      "ZIP Code",
      "City"
    ]

    expected_location_labels.each do |label_text|
      assert_includes location_labels, label_text, "Expected Location modal to include label '#{label_text}'"
    end

    refute_includes location_labels, "Post box"
    refute_includes location_labels, "Zip code"
  end

  test "invoice form and templates use standardized Title Case labels and headers" do
    sign_in @user
    get new_invoice_path
    assert_response :success

    invoice_labels = css_select("label.form-label").map { |el| el.text.strip }
    [
      "Invoice Number",
      "Issue Date",
      "Currency",
      "Payment Due Date",
      "Delivery Date",
      "Locality Name",
      "Message to Recipient",
      "Attachments",
      "Footer Notes"
    ].each do |label_text|
      assert_includes invoice_labels, label_text, "Expected Invoice form to include label '#{label_text}'"
    end

    check_labels = css_select("label.form-check-label").map { |el| el.text.strip }
    assert_includes check_labels, "Save Payment Terms and Means for Future Invoices"
    assert_includes check_labels, "Save Notes for Future Invoices"
    assert_includes check_labels, "Save Footer Notes for Future Invoices"

    headers = css_select("th").map { |el| el.text.strip }
    assert_includes headers, "Price Per Unit"
    refute_includes headers, "Price per unit"

    assert_includes response.body, "Subtotal Excl. Taxes"
    assert_includes response.body, "Total Taxes"

    payment_options = css_select("select#payment_terms_select option").map { |el| el.text.strip }
    assert_includes payment_options, "Add Payment Terms and Means"
    assert_includes payment_options, "Cash Payment"

    h5_headings = css_select("h5").map { |el| el.text.strip }
    assert_includes h5_headings, "Delivery Details"

    assert_select "button.add-footer-toggle-btn", text: "+ Add Footer Notes"

    invoice_card = File.read(Rails.root.join("app/views/invoices/partials/_invoice_card.html.erb"))
    assert_includes invoice_card, "Price / Unit"
    assert_includes invoice_card, "Subtotal Excl. Taxes"
    assert_includes invoice_card, "Total Taxes"
    assert_includes invoice_card, "Incl. Taxes"

    invoice_pdf = File.read(Rails.root.join("app/views/invoices/partials/_invoice_pdf.html.erb"))
    assert_includes invoice_pdf, "Price Per Unit"
    assert_includes invoice_pdf, "Subtotal Excl. Taxes"
    assert_includes invoice_pdf, "Total Taxes"
    assert_includes invoice_pdf, "Total Amount Paid"
    assert_includes invoice_pdf, "Balance Due"
  end

  test "invoice javascript files use standardized Title Case labels and preserve acronyms" do
    options_js = File.read(Rails.root.join("app/javascript/long_select_options/options.js"))
    assert_includes options_js, '"Choose Reason Code"'
    assert_includes options_js, '"Early Payment Allowance Adjustment"'
    assert_includes options_js, '"Add Optional Field"'
    assert_includes options_js, '"File ID"'
    assert_includes options_js, '"HSN/SAC"'
    assert_includes options_js, '"Commodity Classification: ECCN"'
    assert_includes options_js, '"EAN/GTIN"'
    assert_includes options_js, '"Transaction VAT Type"'
    assert_includes options_js, '"Customer Account ID"'
    assert_includes options_js, '"Commission Number of Seller"'

    invoice_js = File.read(Rails.root.join("app/javascript/invoice.js"))
    assert_includes invoice_js, "Add Optional Field"
    assert_includes invoice_js, "Choose Reason Code"
    assert_includes invoice_js, "'+ Add Footer Notes'"
    assert_includes invoice_js, "'− Remove Footer Notes'"
    assert_includes invoice_js, "Price Per Quantity"
    assert_includes invoice_js, "'Price Per Unit'"
    assert_includes invoice_js, 'label: "Commodity Classification: ECCN"'
    assert_includes invoice_js, 'label: "Edit Type (If Needed)"'
    assert_includes invoice_js, 'label: "File ID"'
    assert_includes invoice_js, "Tax Number: ${data.tax_number}"
  end

  test "navigation and authentication views use consistent Title Case labels" do
    get new_user_session_path
    assert_response :success
    session_labels = css_select("label").map { |el| el.text.strip }
    assert_includes session_labels, "Email Address"
    assert_includes session_labels, "Password"
    assert_includes session_labels, "Remember Me"

    get new_user_registration_path
    assert_response :success
    reg_labels = css_select("label").map { |el| el.text.strip }
    assert_includes reg_labels, "Email Address"
    assert_includes reg_labels, "Company Name"
    assert_includes reg_labels, "Password"
    assert_includes reg_labels, "Password Confirmation"

    sign_in @user
    get edit_profile_path
    assert_response :success
    profile_labels = css_select("label.form-label").map { |el| el.text.strip }
    assert_includes profile_labels, "Email Address"
    assert_includes profile_labels, "Preferred Dashboard Currency"
    assert_includes profile_labels, "New Password"
    assert_includes profile_labels, "Confirm New Password"
    assert_includes profile_labels, "Current Password"

    dropdown_items = css_select("a.dropdown-item").map { |el| el.text.strip }
    assert dropdown_items.any? { |text| text.include?("Log Out") }, "Expected user menu to include 'Log Out'"
  end

  test "I18n human_attribute_name translations resolve to Title Case with preserved acronyms" do
    assert_equal "Share Capital", Company.human_attribute_name(:share_capital)
    assert_equal "Registration Address", Company.human_attribute_name(:registration_address)
    assert_equal "Company ID Type", Company.human_attribute_name(:company_id_type)
    assert_equal "Tax ID Type", Company.human_attribute_name(:tax_id_type)
    assert_equal "GLN", Company.human_attribute_name(:gln)
    assert_equal "ZIP Code", Location.human_attribute_name(:zip_code)
    assert_equal "Post Box", Location.human_attribute_name(:post_box)
    assert_equal "Password Confirmation", User.human_attribute_name(:password_confirmation)
    assert_equal "Current Password", User.human_attribute_name(:current_password)
  end
end
