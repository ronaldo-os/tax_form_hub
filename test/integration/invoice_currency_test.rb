require "test_helper"

class InvoiceCurrencyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "currency_inv_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      currency: "PHP"
    )
    @company = Company.create!(name: "Currency Invoicing Co", user: @user)
    @user.update(company: @company)

    @recipient = Company.create!(name: "Client Co", user: @user)
    sign_in @user
  end

  test "new invoice form renders all 8 currencies from User::SUPPORTED_CURRENCIES" do
    get new_invoice_path
    assert_response :success

    assert_select "select#invoice_currency" do
      User::SUPPORTED_CURRENCIES.each do |code, _name|
        assert_select "option[value='#{code}']"
      end
    end
  end

  test "new credit note form renders all 8 currencies from User::SUPPORTED_CURRENCIES" do
    get new_invoice_path(category: "credit_note")
    assert_response :success

    assert_select "select#invoice_currency" do
      User::SUPPORTED_CURRENCIES.each do |code, _name|
        assert_select "option[value='#{code}']"
      end
    end
  end

  test "new quote form renders all 8 currencies from User::SUPPORTED_CURRENCIES" do
    get new_invoice_path(category: "quote")
    assert_response :success

    assert_select "select#invoice_currency" do
      User::SUPPORTED_CURRENCIES.each do |code, _name|
        assert_select "option[value='#{code}']"
      end
    end
  end

  test "invoice, credit note, and quote forms default to user preferred currency from profile" do
    @user.update!(currency: "EUR")

    # Standard invoice
    get new_invoice_path
    assert_response :success
    assert_select "select#invoice_currency option[value='EUR'][selected]"

    # Credit note
    get new_invoice_path(category: "credit_note")
    assert_response :success
    assert_select "select#invoice_currency option[value='EUR'][selected]"

    # Quote
    get new_invoice_path(category: "quote")
    assert_response :success
    assert_select "select#invoice_currency option[value='EUR'][selected]"
  end

  test "creating standard invoice with custom currency persists currency correctly" do
    post invoices_path, params: {
      invoice: {
        invoice_type: "sale",
        invoice_category: "standard",
        currency: "USD",
        invoice_number: "INV-USD-001",
        issue_date: Date.current,
        recipient_company_id: @recipient.id
      }
    }

    assert_response :redirect
    invoice = @user.invoices.find_by(invoice_number: "INV-USD-001")
    assert_not_nil invoice
    assert_equal "USD", invoice.currency
  end

  test "creating credit note with custom currency persists currency correctly" do
    # Original invoice in EUR
    original = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      currency: "EUR",
      invoice_number: "INV-ORIG-001",
      issue_date: Date.current,
      recipient_company_id: @recipient.id,
      status: "sent"
    )

    post invoices_path, params: {
      invoice: {
        invoice_type: "sale",
        invoice_category: "credit_note",
        credit_note_original_invoice_id: original.id,
        currency: "JPY",
        invoice_number: "CN-JPY-001",
        issue_date: Date.current,
        recipient_company_id: @recipient.id
      }
    }

    assert_response :redirect
    credit_note = @user.invoices.find_by(invoice_number: "CN-JPY-001")
    assert_not_nil credit_note
    assert_equal "JPY", credit_note.currency
    assert_equal "credit_note", credit_note.invoice_category
  end

  test "creating quote with custom currency persists currency correctly" do
    post invoices_path, params: {
      invoice: {
        invoice_type: "sale",
        invoice_category: "quote",
        currency: "CAD",
        invoice_number: "Q-CAD-001",
        issue_date: Date.current,
        recipient_company_id: @recipient.id
      }
    }

    assert_response :redirect
    quote = @user.invoices.find_by(invoice_number: "Q-CAD-001")
    assert_not_nil quote
    assert_equal "CAD", quote.currency
    assert_equal "quote", quote.invoice_category
  end

  test "invoice currency validation rejects unsupported currency codes" do
    invoice = Invoice.new(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      currency: "XYZ",
      invoice_number: "INV-INVALID-001"
    )

    assert_not invoice.valid?
    assert_includes invoice.errors[:currency], "is not included in the list"
  end

  test "form options display currency symbols like $ instead of only codes" do
    get new_invoice_path
    assert_response :success

    assert_select "select#invoice_currency option[value='USD']", text: "$ — US Dollar (USD)"
    assert_select "select#invoice_currency option[value='PHP']", text: "₱ — Philippine Peso (PHP)"
    assert_select "select#invoice_currency option[value='EUR']", text: "€ — Euro (EUR)"
    assert_select "select#invoice_currency option[value='GBP']", text: "£ — British Pound (GBP)"
    assert_select "select#invoice_currency option[value='JPY']", text: "¥ — Japanese Yen (JPY)"
  end

  test "form totals render the actual symbol of the user preferred currency" do
    @user.update!(currency: "USD")
    get new_invoice_path
    assert_response :success

    assert_select "h4 .currency_type", text: "$"
    assert_select "p#total-taxes-row .currency_type", text: "$"
  end

  test "invoice view and index table render currency symbol" do
    invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      currency: "USD",
      invoice_number: "INV-SYM-001",
      issue_date: Date.current,
      recipient_company_id: @recipient.id,
      total: { "grand_total" => "150.00", "subtotal" => "150.00", "tax" => "0.00" },
      status: "sent"
    )

    # Show page card
    get invoice_path(invoice)
    assert_response :success
    assert_select ".totals-section", text: /\$\s*150\.00/

    # Datatable endpoint
    get datatable_data_invoices_url, params: { invoice_type: "sale", format: :json }
    assert_response :success
    data = JSON.parse(response.body)["data"]
    assert_not_empty data
    assert_match /\$\s*150\.00/, data.first["total"]
  end

  test "eligible_invoices JSON returns currency for each invoice" do
    Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      currency: "GBP",
      invoice_number: "INV-GBP-001",
      issue_date: Date.current,
      recipient_company_id: @recipient.id,
      status: "sent"
    )

    get "/invoices/fetch_eligible.json", params: {
      recipient_company_id: @recipient.id,
      invoice_type: "sale"
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_not_empty json
    found = json.find { |item| item["invoice_number"] == "INV-GBP-001" }
    assert_not_nil found
    assert_equal "GBP", found["currency"]
  end
end
