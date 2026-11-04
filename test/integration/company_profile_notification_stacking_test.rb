require "test_helper"

class CompanyProfileNotificationStackingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @app_css_source = File.read(Rails.root.join("app/assets/stylesheets/src/application.css"))
    @critical_css_source = File.read(Rails.root.join("app/assets/stylesheets/src/critical.css"))
    @app_css_build = File.read(Rails.root.join("app/assets/builds/application.css"))
    @critical_css_build = File.read(Rails.root.join("app/assets/builds/critical.css"))
    @company_css = File.read(Rails.root.join("app/assets/stylesheets/company.css"))
    @notifications_css = File.read(Rails.root.join("app/assets/stylesheets/notifications.css"))
    @app_js = File.read(Rails.root.join("app/javascript/application.js"))
  end

  test "notification popup z-index is higher than floating company profile action header bar" do
    # Extract z-index of .custom_tfh_alert
    alert_match = @app_css_source.match(/\.custom_tfh_alert\s*\{[^}]*z-index:\s*(\d+)\s*!important/m)
    assert_not_nil alert_match, "Expected .custom_tfh_alert to define an explicit z-index"
    alert_z_index = alert_match[1].to_i

    # Extract z-index of .companies-header-bar
    header_bar_match = @company_css.match(/\.companies-header-bar\s*\{[^}]*z-index:\s*(\d+)/m)
    assert_not_nil header_bar_match, "Expected .companies-header-bar to define a z-index"
    header_bar_z_index = header_bar_match[1].to_i

    # Extract z-index of .modern-notification-dropdown-menu
    notif_dropdown_match = @notifications_css.match(/\.modern-notification-dropdown-menu\s*\{[^}]*z-index:\s*(\d+)/m)
    assert_not_nil notif_dropdown_match, "Expected .modern-notification-dropdown-menu to define a z-index"
    notif_dropdown_z_index = notif_dropdown_match[1].to_i

    assert_operator alert_z_index, :>, header_bar_z_index,
      "Notification alert z-index (#{alert_z_index}) must be above .companies-header-bar (#{header_bar_z_index})"
    assert_operator notif_dropdown_z_index, :>, header_bar_z_index,
      "Notification dropdown menu z-index (#{notif_dropdown_z_index}) must be above .companies-header-bar (#{header_bar_z_index})"

    # Verify compiled CSS bundles contain the updated z-index
    assert_match(/z-index:\s*100010\s*!important/, @app_css_build)
    assert_match(/z-index:\s*100010\s*!important/, @critical_css_build)

    # Verify JS showFlashMessage uses matching top/right positioning and z-index
    assert_includes @app_js, "top: 70px; right: 20px; z-index: 100010;"
  end

  test "notification popup and floating action section support both light mode and dark mode" do
    [ @app_css_source, @critical_css_source ].each do |css|
      assert_match(/\.custom_tfh_alert\s*\{[^}]*background:\s*var\(--card-bg,\s*#ffffff\)/m, css)
      assert_match(/\.custom_tfh_alert\s*\{[^}]*color:\s*var\(--text-main,\s*#080808\)/m, css)
      assert_match(/\[data-theme="dark"\]\s*\.custom_tfh_alert\s*\{[^}]*background:\s*var\(--card-bg,\s*#1e293b\)/m, css)
      assert_match(/\[data-theme="dark"\]\s*\.custom_tfh_alert\s*\{[^}]*color:\s*var\(--text-main,\s*#f8f9fa\)/m, css)
    end

    assert_match(/\[data-theme="dark"\]\s*\.alert_text_success/, @app_css_source)
    assert_match(/\[data-theme="dark"\]\s*\.alert_text_danger/, @app_css_source)
    assert_match(/\[data-theme="dark"\]\s*\.companies-header-bar/, @company_css)
  end

  test "company profile page preserves floating action buttons and displays notification popup on update" do
    user = User.create!(
      email: "company_notif_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    company = Company.create!(
      name: "Initial Company Name",
      country: "Philippines",
      user: user
    )
    user.update!(company: company)
    sign_in user

    patch company_path(company), params: {
      company: {
        name: "Updated Company Name",
        country: "Philippines"
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Verify floating action bar and its three buttons remain intact
    assert_select ".companies-header-bar" do
      assert_select "a.btn-back span", text: "Back"
      assert_select "a.btn-outline-primary span", text: "View As Visitor"
      assert_select "button#update-company-btn-top span", text: "Save Changes"
    end

    # Verify notification popup renders with the update message
    assert_select ".custom_tfh_alert", text: /Company profile updated\./
  end
end
