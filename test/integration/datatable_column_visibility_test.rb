require "test_helper"

class DatatableColumnVisibilityTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "colvis_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "ColVis Test Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user
  end

  test "all datatable modules wire column visibility persistence" do
    datatable_modules = %w[
      app/javascript/index_invoice.js
      app/javascript/client_submissions.js
      app/javascript/admin_client_submissions.js
      app/javascript/locations.js
      app/javascript/subscriptions.js
    ]

    datatable_modules.each do |relative_path|
      content = File.read(Rails.root.join(relative_path))
      assert_includes content, "initDataTableColumnVisibility",
                      "Expected #{relative_path} to wire initDataTableColumnVisibility"
    end
  end

  test "column visibility module uses safe DOM APIs and localStorage persistence" do
    module_src = File.read(Rails.root.join("app/javascript/datatable_column_visibility.js"))

    assert_includes module_src, "window.localStorage.getItem"
    assert_includes module_src, "window.localStorage.setItem"
    assert_includes module_src, "window.localStorage.removeItem"
    assert_includes module_src, "document.createElement"
    refute_match(/\.innerHTML\s*=/, module_src, "Must not assign innerHTML in datatable_column_visibility.js")
  end

  test "built CSS includes column visibility styles for light and dark themes" do
    css_src = File.read(Rails.root.join("app/assets/stylesheets/src/application.css"))
    built_css = File.read(Rails.root.join("app/assets/builds/application.css"))

    assert_includes css_src, ".dt-colvis-btn"
    assert_includes css_src, ".dt-colvis-menu"
    assert_includes css_src, '[data-theme="dark"] .dt-colvis-menu'
    assert_includes built_css, ".dt-colvis-btn"
    assert_includes built_css, ".dt-colvis-menu"
  end

  test "all datatable pages render successfully with identifiable table headers" do
    get invoices_path
    assert_response :success
    assert_select "table#sales-table thead th", minimum: 4

    get tax_submissions_home_path
    assert_response :success
    assert_select "table.submissionsTable thead th", minimum: 4

    get tax_submissions_path
    assert_response :success
    assert_select "table#taxSubmissionsTableActive thead th", minimum: 4

    get locations_path
    assert_response :success
    assert_select "table#location-table thead th", minimum: 4

    get subscriptions_path
    assert_response :success
    assert_select "table.subscription-table thead th", minimum: 4
  end
end
