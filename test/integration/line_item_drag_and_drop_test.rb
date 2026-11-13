require "test_helper"

class LineItemDragAndDropTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "dnd_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Sender Corp", country: "Philippines", user: @user)
    @recipient = Company.create!(name: "Recipient Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "new standard invoice, quote, and credit note render drag-and-drop handle in line items table" do
    [
      new_invoice_path,
      new_invoice_path(category: "quote"),
      new_invoice_path(category: "credit_note")
    ].each do |path|
      get path
      assert_response :success
      assert_select "#line-items tr.line-item td.line-item-actions-cell .line-item-drag-handle i.fa-grip-vertical", minimum: 1
    end
  end

  test "edit standard invoice, quote, and credit note include line item data and drag-and-drop support" do
    ["standard", "quote", "credit_note"].each_with_index do |category, idx|
      doc = Invoice.create!(
        user: @user,
        sale_from: @company,
        recipient_company: @recipient,
        invoice_number: "DND-EDIT-#{category.upcase}-#{idx}",
        invoice_type: "sale",
        invoice_category: category,
        status: "draft",
        issue_date: Date.current,
        payment_terms: { "cash" => { "cash.due_date" => 30.days.from_now.to_date.to_s } },
        currency: "PHP",
        line_items_data: [
          { "item_id" => "A1", "description" => "First Item", "quantity" => "1", "unit" => "pcs", "price" => "100.00", "tax" => "0", "total" => "100.00" },
          { "item_id" => "B2", "description" => "Second Item", "quantity" => "2", "unit" => "pcs", "price" => "250.00", "tax" => "0", "total" => "500.00" }
        ]
      )

      get edit_invoice_path(doc)
      assert_response :success
      assert_select "tbody#line-items[data-line-items]"
    end
  end

  test "updating an invoice, quote, or credit note persists reordered line items and their optional fields" do
    ["standard", "quote", "credit_note"].each_with_index do |category, idx|
      doc = Invoice.create!(
        user: @user,
        sale_from: @company,
        recipient_company: @recipient,
        invoice_number: "DND-REORDER-#{category.upcase}-#{idx}",
        invoice_type: "sale",
        invoice_category: category,
        status: "draft",
        issue_date: Date.current,
        payment_terms: { "cash" => { "cash.due_date" => 30.days.from_now.to_date.to_s } },
        currency: "PHP",
        line_items_data: [
          { "item_id" => "ITEM-1", "description" => "Original First", "quantity" => "1", "unit" => "pcs", "price" => "100.00", "tax" => "0", "total" => "100.00" },
          { "item_id" => "ITEM-2", "description" => "Original Second", "quantity" => "2", "unit" => "pcs", "price" => "200.00", "tax" => "0", "total" => "400.00" },
          { "item_id" => "ITEM-3", "description" => "Original Third", "quantity" => "3", "unit" => "pcs", "price" => "300.00", "tax" => "0", "total" => "900.00" }
        ]
      )

      # Simulate submitting after dragging ITEM-3 to index 0, ITEM-1 to index 1, ITEM-2 to index 2
      patch invoice_path(doc), params: {
        invoice: {
          recipient_company_id: @recipient.id,
          invoice_number: doc.invoice_number,
          issue_date: Date.current.to_s,
          currency: "PHP",
          invoice_type: "sale",
          invoice_category: category,
          line_items_attributes: {
            "0" => {
              item_id: "ITEM-3",
              description: "Original Third",
              quantity: "3",
              unit: "pcs",
              price: "300.00",
              tax: "0",
              total: "900.00",
              optional_fields: { "note.notes.text.4" => "Moved to top" }
            },
            "1" => {
              item_id: "ITEM-1",
              description: "Original First",
              quantity: "1",
              unit: "pcs",
              price: "100.00",
              tax: "0",
              total: "100.00"
            },
            "2" => {
              item_id: "ITEM-2",
              description: "Original Second",
              quantity: "2",
              unit: "pcs",
              price: "200.00",
              tax: "0",
              total: "400.00"
            }
          }
        }
      }

      assert_redirected_to invoice_path(doc)
      doc.reload
      assert_equal ["ITEM-3", "ITEM-1", "ITEM-2"], doc.line_items_data.map { |li| li["item_id"] }
      assert_equal "Moved to top", doc.line_items_data.first.dig("optional_fields", "note", "notes.text.4")
    end
  end

  test "invoice javascript and stylesheet include drag-and-drop reordering implementation" do
    js_content = File.read(Rails.root.join("app/javascript/invoice.js"))
    assert_includes js_content, "line-item-drag-handle"
    assert_includes js_content, "function reindexLineItems()"
    assert_includes js_content, "function moveLineItemGroup("
    assert_includes js_content, "dragstart.line_item_dnd"
    assert_includes js_content, "touchmove.line_item_dnd"
    assert_includes js_content, "keydown.line_item_dnd"

    css_content = File.read(Rails.root.join("app/assets/stylesheets/invoices.css"))
    assert_includes css_content, ".line-item-drag-handle"
    assert_includes css_content, ".line-item-dragging"
    assert_includes css_content, ".line-item-drop-above"
    assert_includes css_content, ".line-item-drop-below"
  end
end
