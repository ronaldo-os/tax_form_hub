require "test_helper"

class ActionSpamPreventionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "spam_prevent_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Test Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "locations page renders and processes creation action button cleanly" do
    get locations_path
    assert_response :success
    assert_select "form[action='/locations']"
    assert_select "input[type='submit'][value='Save Location']"

    assert_difference("Location.count", 1) do
      post locations_path, params: {
        location: {
          location_type: "Ship From",
          location_name: "Warehouse Alpha",
          street: "123 Port Road",
          city: "Manila",
          country: "Philippines"
        }
      }
    end
    assert_redirected_to locations_path
  end

  test "notifications bulk action processes bulk_action parameter properly" do
    notification = Notification.create!(
      recipient: @user,
      category: "invoices",
      action: "invoice_sent",
      title: "Test Alert",
      read_at: nil
    )

    post bulk_action_notifications_path, params: {
      bulk_action: "mark_read",
      notification_ids: [notification.id]
    }
    assert_redirected_to notifications_path

    notification.reload
    assert notification.read?, "Notification should be marked read via bulk action"
  end

  test "invoice creation retains commit_action submit parameter" do
    recipient = Company.create!(name: "Recipient Inc", country: "Philippines", user: @user)

    assert_difference("Invoice.count", 1) do
      post invoices_path, params: {
        commit_action: "save",
        invoice: {
          invoice_type: "sale",
          invoice_category: "standard",
          recipient_company_id: recipient.id,
          currency: "PHP",
          issue_date: Date.current.to_s,
          due_date: (Date.current + 30.days).to_s,
          payment_terms: "net_30"
        }
      }
    end

    created_invoice = Invoice.last
    assert_equal "draft", created_invoice.status
    assert_redirected_to invoices_path
  end

  test "application layout includes compiled assets and disables turbo hover prefetching" do
    get root_path
    assert_response :success
    assert_select "script[type='module']"
    assert_select "link[rel='stylesheet'][href*='application']"
    assert_select "meta[name='turbo-prefetch'][content='false']"
  end

  test "action_spam_prevention coordinates simultaneous action buttons, turbo submit events, and page redirects" do
    js_source = File.read(Rails.root.join("app/javascript/action_spam_prevention.js"))

    assert_includes js_source, "pageActionInFlight"
    assert_includes js_source, "setPageActionInFlight"
    assert_includes js_source, "abortPendingBackgroundRequests"
    assert_includes js_source, "closeOpenDropdownMenus"
    assert_includes js_source, "navigationInFlightUrl"
    assert_includes js_source, "turbo:submit-start"
    assert_includes js_source, "turbo:before-visit"
    refute_includes js_source, "if (event.defaultPrevented) {\n        resetFormSubmitting(form);"
  end

  test "tax submission modals defer PDF embed loading via data-src until modal open" do
    partial_paths = [
      Rails.root.join("app/views/tax_submissions/_submission_table.html.erb"),
      Rails.root.join("app/views/tax_submissions/_submission_table_incoming.html.erb"),
      Rails.root.join("app/views/admin/tax_submissions/_submission_table.html.erb")
    ]

    partial_paths.each do |path|
      content = File.read(path)
      assert_includes content, '<embed data-src="<%= url_for(', "Expected #{path} to defer PDF embed loading with data-src"
      refute_includes content, '<embed src="<%= url_for(', "Expected #{path} not to eagerly load PDFs in hidden modals"
    end

    app_js = File.read(Rails.root.join("app/javascript/application.js"))
    assert_includes app_js, "hydrateLazyModalMedia"
    assert_includes app_js, "show.bs.modal"
  end

  test "smart back button handler respects explicit href targets instead of history.back loops" do
    app_js = File.read(Rails.root.join("app/javascript/application.js"))
    assert_includes app_js, "hasExplicitHref"
    assert_includes app_js, "targetUrl.pathname !== currentUrl.pathname || targetUrl.search !== currentUrl.search"
  end
end
