require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "payer_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Test Seller Inc.", user: @user)
    @invoice = Invoice.create!(
      user: @user,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-PAY-#{rand(10000)}",
      status: "sent",
      currency: "PHP",
      total: { "subtotal" => "1000.00", "grand_total" => "1000.00" }
    )
  end

  test "valid payment with required fields" do
    payment = @invoice.payments.build(
      user: @user,
      payment_method: "Bank Transfer",
      reference_number: "BT-12345678",
      payment_date: Date.current,
      amount: 400.00,
      notes: "First installment"
    )

    assert payment.valid?, "Payment should be valid with allowed attributes"
    assert payment.save
    assert_equal 1, @invoice.payments.count
    assert_equal 400.00, @invoice.total_paid
    assert_equal 600.00, @invoice.remaining_balance
  end

  test "validates payment_method against allow-list" do
    Payment::PAYMENT_METHODS.each do |method|
      payment = @invoice.payments.build(
        user: @user,
        payment_method: method,
        reference_number: "REF-#{rand(1000)}",
        payment_date: Date.current,
        amount: 100.00
      )
      assert payment.valid?, "#{method} should be a valid payment method"
    end

    invalid_payment = @invoice.payments.build(
      user: @user,
      payment_method: "Bitcoin",
      reference_number: "BTC-123",
      payment_date: Date.current,
      amount: 100.00
    )
    assert_not invalid_payment.valid?
    assert_includes invalid_payment.errors[:payment_method].first, "is not a valid payment method"
  end

  test "validates presence of required fields" do
    payment = Payment.new
    assert_not payment.valid?
    assert payment.errors[:payment_method].present?
    assert payment.errors[:reference_number].present?
    assert payment.errors[:payment_date].present?
    assert payment.errors[:amount].present?
  end

  test "validates amount cannot exceed remaining balance" do
    overpayment = @invoice.payments.build(
      user: @user,
      payment_method: "GCash",
      reference_number: "GC-123456",
      payment_date: Date.current,
      amount: 1200.00
    )

    assert_not overpayment.valid?
    assert_includes overpayment.errors[:amount].first, "cannot exceed the remaining balance"
  end

  test "supports multiple partial payments up to total balance" do
    p1 = @invoice.payments.create!(
      user: @user,
      payment_method: "GCash",
      reference_number: "GC-001",
      payment_date: Date.current,
      amount: 300.00
    )
    assert_equal 300.00, @invoice.total_paid
    assert_equal 700.00, @invoice.remaining_balance

    p2 = @invoice.payments.create!(
      user: @user,
      payment_method: "Maya",
      reference_number: "MY-002",
      payment_date: Date.current,
      amount: 400.00
    )
    assert_equal 700.00, @invoice.total_paid
    assert_equal 300.00, @invoice.remaining_balance

    p3 = @invoice.payments.create!(
      user: @user,
      payment_method: "Check",
      reference_number: "CHK-003",
      payment_date: Date.current,
      amount: 300.00
    )
    assert_equal 1000.00, @invoice.total_paid
    assert_equal 0.00, @invoice.remaining_balance
  end

  test "formatted_amount and styling helpers" do
    payment = @invoice.payments.build(
      payment_method: "Maya",
      amount: 250.50
    )
    assert_equal "₱ 250.50", payment.formatted_amount
    assert_equal "fa-solid fa-wallet", payment.payment_method_icon
    assert_includes payment.payment_method_badge_class, "text-success"
  end
end
