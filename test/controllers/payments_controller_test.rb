require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @seller = User.create!(
      email: "seller_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @buyer = User.create!(
      email: "buyer_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )

    @seller_company = Company.create!(name: "Seller Corp", user: @seller)
    @buyer_company = Company.create!(name: "Buyer Corp", user: @buyer)

    @sale_invoice = Invoice.create!(
      user: @seller,
      sale_from: @seller_company,
      recipient_company: @buyer_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-PAY-#{rand(10000)}",
      status: "sent",
      currency: "PHP",
      total: { "subtotal" => "1000.00", "grand_total" => "1000.00" }
    )

    # Counterpart purchase invoice for buyer
    @purchase_invoice = Invoice.create!(
      user: @buyer,
      sale_from: @seller_company,
      recipient_company: @buyer_company,
      invoice_type: "purchase",
      invoice_category: "standard",
      invoice_number: @sale_invoice.invoice_number,
      status: "pending",
      currency: "PHP",
      total: { "subtotal" => "1000.00", "grand_total" => "1000.00" }
    )
  end

  test "seller can mark invoice as partially paid and log payment receipt" do
    sign_in @seller

    assert_difference -> { @sale_invoice.payments.count }, 1 do
      post record_payment_invoice_url(@sale_invoice), params: {
        payment: {
          payment_method: "GCash",
          reference_number: "GC-987654",
          payment_date: Date.current,
          amount: "400.00",
          notes: "Partial payment via GCash"
        }
      }
    end

    assert_response :redirect
    @sale_invoice.reload
    assert_equal "partially_paid", @sale_invoice.status
    assert_equal 400.00, @sale_invoice.total_paid
    assert_equal 600.00, @sale_invoice.remaining_balance

    # Verify counterpart purchase invoice was updated
    @purchase_invoice.reload
    assert_equal "partially_paid", @purchase_invoice.status
    assert_equal 1, @purchase_invoice.payments.count
    assert_equal 400.00, @purchase_invoice.total_paid

    # Verify activity was logged
    activity = Activity.where(trackable: @sale_invoice).order(created_at: :desc).first
    assert_not_nil activity
    assert_equal "payment_recorded", activity.action
    assert_match /GCash/, activity.description
    assert_match /Partially Paid/, activity.description

    # Verify counterparty notification
    notification = Notification.where(recipient_id: @buyer.id).order(created_at: :desc).first
    assert_not_nil notification
    assert_equal "invoice_partially_paid", notification.action
  end

  test "logging remaining balance marks invoice as paid" do
    sign_in @seller

    post record_payment_invoice_url(@sale_invoice), params: {
      payment: {
        payment_method: "Bank Transfer",
        reference_number: "BT-FULL-112233",
        payment_date: Date.current,
        amount: "1000.00",
        notes: "Full payment settlement"
      }
    }

    assert_response :redirect
    @sale_invoice.reload
    assert_equal "paid", @sale_invoice.status
    assert_equal 1000.00, @sale_invoice.total_paid
    assert_equal 0.00, @sale_invoice.remaining_balance

    @purchase_invoice.reload
    assert_equal "paid", @purchase_invoice.status
  end

  test "multi-transaction partial payments transition to paid when completed" do
    sign_in @seller

    # Transaction 1: 300 via Maya
    post record_payment_invoice_url(@sale_invoice), params: {
      payment: {
        payment_method: "Maya",
        reference_number: "MY-111",
        payment_date: Date.current,
        amount: "300.00"
      }
    }
    @sale_invoice.reload
    assert_equal "partially_paid", @sale_invoice.status
    assert_equal 700.00, @sale_invoice.remaining_balance

    # Transaction 2: 400 via Check
    post record_payment_invoice_url(@sale_invoice), params: {
      payment: {
        payment_method: "Check",
        reference_number: "CHK-222",
        payment_date: Date.current,
        amount: "400.00"
      }
    }
    @sale_invoice.reload
    assert_equal "partially_paid", @sale_invoice.status
    assert_equal 300.00, @sale_invoice.remaining_balance

    # Transaction 3: 300 via Bank Transfer (Final)
    post record_payment_invoice_url(@sale_invoice), params: {
      payment: {
        payment_method: "Bank Transfer",
        reference_number: "BT-333",
        payment_date: Date.current,
        amount: "300.00"
      }
    }
    @sale_invoice.reload
    assert_equal "paid", @sale_invoice.status
    assert_equal 0.00, @sale_invoice.remaining_balance
    assert_equal 3, @sale_invoice.payments.count
  end

  test "buyer cannot record payments on purchase invoice" do
    sign_in @buyer

    post record_payment_invoice_url(@purchase_invoice), params: {
      payment: {
        payment_method: "GCash",
        reference_number: "GC-HACK",
        payment_date: Date.current,
        amount: "100.00"
      }
    }

    assert_response :redirect
    assert_equal "Receiver of invoice cannot log payments. Only the issuer can log payments.", flash[:alert]
  end

  test "destroying a payment recalculates invoice status" do
    sign_in @seller

    payment = @sale_invoice.payments.create!(
      user: @seller,
      payment_method: "GCash",
      reference_number: "GC-001",
      payment_date: Date.current,
      amount: 400.00
    )
    @sale_invoice.update!(status: "partially_paid")

    delete invoice_payment_url(@sale_invoice, payment)
    assert_response :redirect

    @sale_invoice.reload
    assert_equal "sent", @sale_invoice.status
    assert_equal 0.0, @sale_invoice.total_paid
  end

  test "datatable displays Partially Paid status accurately" do
    @sale_invoice.update!(status: "partially_paid")
    sign_in @seller

    get datatable_data_invoices_url, params: { invoice_type: "sale", format: :json }
    assert_response :success

    json = JSON.parse(response.body)
    data = json["data"]
    match = data.find { |row| row["DT_RowId"] == "invoice_#{@sale_invoice.id}" }
    assert_not_nil match
    assert_equal "Partially Paid", match["status"]
  end
end
