require "test_helper"

class FormFieldStylingStandardizationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @app_css_source = File.read(Rails.root.join("app/assets/stylesheets/src/application.css"))
    @critical_css_source = File.read(Rails.root.join("app/assets/stylesheets/src/critical.css"))
    @app_css_build = File.read(Rails.root.join("app/assets/builds/application.css"))
    @critical_css_build = File.read(Rails.root.join("app/assets/builds/critical.css"))
    @profile_css = File.read(Rails.root.join("app/assets/stylesheets/profile.css"))
    @company_css = File.read(Rails.root.join("app/assets/stylesheets/company.css"))
    @invoices_css = File.read(Rails.root.join("app/assets/stylesheets/invoices.css"))
    @notifications_css = File.read(Rails.root.join("app/assets/stylesheets/notifications.css"))
    @responsive_css = File.read(Rails.root.join("app/assets/stylesheets/responsive.css"))
  end

  test "defines standardized form field design tokens for both light and dark mode" do
    [ @app_css_source, @critical_css_source, @app_css_build, @critical_css_build ].each do |css|
      assert_includes css, "--form-field-radius"
      assert_includes css, "--bs-border-radius-md"
      assert_includes css, "--form-field-height"
      assert_includes css, "--form-field-height-sm"
      assert_includes css, "--form-field-height-lg"
      assert_includes css, "--form-field-bg"
      assert_includes css, "--form-field-text"
      assert_includes css, "--form-field-border"
      assert_includes css, "--form-field-hover-border"
      assert_includes css, "--form-field-focus-border"
      assert_includes css, "--form-field-focus-ring"
      assert_includes css, "--form-field-disabled-bg"
      assert_includes css, "--form-field-disabled-text"
      assert_includes css, "--form-field-readonly-bg"
      assert_includes css, "--form-field-error-border"
      assert_includes css, "--form-field-error-ring"
    end

    assert_match(/--form-field-radius:\s*0\.5rem/, @app_css_source)
    assert_match(/--bs-border-radius-md:\s*0\.5rem/, @app_css_source)
    assert_match(/\[data-theme="dark"\][\s\S]*?--form-field-border:\s*#495057/, @app_css_source)
  end

  test "establishes uniform border radius and sizing across form controls, selects, textareas, file inputs, and date pickers" do
    assert_match(/border-radius:\s*var\(--form-field-radius\)\s*!important/, @app_css_source)
    assert_match(/height:\s*var\(--form-field-height\)/, @app_css_source)
    assert_match(/height:\s*var\(--form-field-height-sm\)/, @app_css_source)
    assert_match(/height:\s*var\(--form-field-height-lg\)/, @app_css_source)
    assert_match(/textarea\.form-control/, @app_css_source)
    assert_match(/input\[type="file"\]::file-selector-button/, @app_css_source)
    assert_match(/\[data-theme="dark"\]\s*input\[type="date"\][\s\S]*?color-scheme:\s*dark/, @app_css_source)
  end

  test "maintains clear visual distinctions for hover, focus, disabled, read-only, and error states" do
    # Hover state
    assert_includes @app_css_source, ".form-control:hover:not(:disabled):not([readonly]):not(:focus):not(.is-invalid)"
    assert_includes @app_css_source, "border-color: var(--form-field-hover-border);"

    # Focus state
    assert_includes @app_css_source, "border-color: var(--form-field-focus-border) !important;"
    assert_includes @app_css_source, "box-shadow: var(--form-field-focus-ring) !important;"

    # Disabled state
    assert_includes @app_css_source, ".form-control:disabled"
    assert_includes @app_css_source, "background-color: var(--form-field-disabled-bg) !important;"
    assert_includes @app_css_source, "cursor: not-allowed;"

    # Read-only state
    assert_includes @app_css_source, ".form-control[readonly]:not(:disabled)"
    assert_includes @app_css_source, "background-color: var(--form-field-readonly-bg) !important;"
    assert_includes @app_css_source, "border-style: dashed !important;"

    # Error / Validation state
    assert_includes @app_css_source, ".form-control.is-invalid"
    assert_includes @app_css_source, ".field_with_errors .form-control"
    assert_includes @app_css_source, "border-color: var(--form-field-error-border) !important;"
    assert_includes @app_css_source, "box-shadow: var(--form-field-error-ring) !important;"
  end

  test "aligns input-group outer and inner corners seamlessly across stylesheets" do
    assert_includes @app_css_source, ".input-group:not(.search-input-group) > :first-child:not(:last-child)"
    assert_includes @app_css_source, "border-top-right-radius: 0 !important;"
    assert_includes @app_css_source, "border-top-left-radius: 0 !important;"

    # Profile, Company, Invoices, Notifications, Responsive stylesheets use --form-field-radius
    assert_includes @profile_css, "var(--form-field-radius, 0.5rem)"
    refute_includes @profile_css, "border-radius: 0.65rem"

    assert_includes @company_css, "var(--form-field-radius, 0.5rem)"
    assert_includes @invoices_css, "var(--form-field-radius, 0.5rem)"
    assert_includes @notifications_css, "var(--form-field-radius, 0.5rem)"
    assert_includes @responsive_css, "var(--form-field-radius, 0.5rem)"

    # Record payment modal uses --form-field-radius instead of 4px
    assert_match(/\.record-payment-modal\s+\.form-control[\s\S]*?border-radius:\s*var\(--form-field-radius\)\s*!important/, @app_css_source)
  end

  test "renders standardized form controls on authentication and application pages" do
    get new_user_session_path
    assert_response :success
    assert_select "input.form-control[type='email']"
    assert_select ".input-group input.form-control[type='password']"
    assert_select ".input-group .input-group-text"

    user = User.create!(
      email: "form_style_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    company = Company.create!(name: "Form Style Corp", country: "Philippines", user: user)
    user.update!(company: company)
    sign_in user

    get profile_path
    assert_response :success
    assert_select "input.form-control[type='email']"
    assert_select "select.form-select#user_currency_select"
    assert_select ".input-group input.form-control[type='password']"

    get locations_path
    assert_response :success
    assert_select "input.form-control"
    assert_select "select.form-select"

    get networks_path
    assert_response :success
    assert_select ".search-input-group input.form-control"
  end
end
