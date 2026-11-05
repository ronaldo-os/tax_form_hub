require "test_helper"

class SkeletonLoadersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "skeleton_test_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @company = Company.create!(name: "Skeleton Test Corp", country: "Philippines", user: @user)
    @user.update!(company: @company)
    sign_in @user

    @invoice = Invoice.create!(
      user: @user,
      sale_from: @company,
      recipient_company: @company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-SKEL-#{Time.now.to_i}",
      issue_date: Date.current,
      currency: "PHP",
      status: "draft"
    )

    @app_css = File.read(Rails.root.join("app/assets/stylesheets/src/application.css"))
    @critical_css = File.read(Rails.root.join("app/assets/stylesheets/src/critical.css"))
    @skeleton_css = File.read(Rails.root.join("app/assets/stylesheets/skeleton.css"))
    @dashboard_js = File.read(Rails.root.join("app/javascript/dashboard.js"))
    @client_submissions_js = File.read(Rails.root.join("app/javascript/client_submissions.js"))
    @notifications_controller_js = File.read(Rails.root.join("app/javascript/controllers/notifications_controller.js"))
    @skeleton_loader_js = File.read(Rails.root.join("app/javascript/skeleton_loader.js"))
  end

  test "dashboard renders skeleton loader and wraps content with noscript fallback" do
    get root_path
    assert_response :success

    assert_select "#dashboard_skeleton" do
      assert_select ".analytics-dashboard-skeleton"
      assert_select ".dashboard-header-card"
      assert_select ".bento-card"
      assert_select ".skeleton-chart-container"
      assert_select ".skeleton-donut"
    end

    assert_select "#dashboard_content[style*='display: none']" do
      assert_select "#performanceTrendChart"
      assert_select "#statusDonutChart"
    end

    assert_select "noscript" do
      assert_match(/#dashboard_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#dashboard_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "tax submissions home renders skeleton loader and wraps content with noscript fallback" do
    get tax_submissions_home_path
    assert_response :success

    assert_select "#tax_submissions_skeleton" do
      assert_select ".tax-submissions-skeleton"
      assert_select ".skeleton-table"
      assert_select "thead.table-light"
    end

    assert_select "#tax_submissions_content[style*='display: none']" do
      assert_select "#submissionTabs"
      assert_select "#taxSubmissionsSentActive"
      assert_select "#taxSubmissionsSentArchived"
    end

    assert_select "noscript" do
      assert_match(/#tax_submissions_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#tax_submissions_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "notifications page renders skeleton loader and wraps content with noscript fallback" do
    get notifications_path
    assert_response :success

    assert_select "#notifications_skeleton" do
      assert_select ".notifications-skeleton"
      assert_select ".stat-widget-card"
      assert_select ".notification-page-card"
    end

    assert_select "#notifications_content[style*='display: none']" do
      assert_select "#notifications_header_bar"
      assert_select "#notifications_stat_cards"
    end

    assert_select "noscript" do
      assert_match(/#notifications_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#notifications_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "invoices index renders skeleton loader and wraps content with noscript fallback" do
    get invoices_path
    assert_response :success

    assert_select "#invoices_skeleton" do
      assert_select ".invoices-page-skeleton"
      assert_select ".invoice-stats-row"
      assert_select ".skeleton-table"
    end

    assert_select "#invoices_content[style*='display: none']" do
      assert_select "#submissionTabs"
      assert_select "#invoiceTabsContent"
    end

    assert_select "noscript" do
      assert_match(/#invoices_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#invoices_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "invoices show renders skeleton loader and wraps content with noscript fallback" do
    get invoice_path(@invoice)
    assert_response :success

    assert_select "#invoice_show_skeleton" do
      assert_select ".invoice-show-skeleton"
      assert_select ".skeleton-table"
    end

    assert_select "#invoice_show_content[style*='display: none']" do
      assert_select "#invoice_card"
    end

    assert_select "noscript" do
      assert_match(/#invoice_show_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#invoice_show_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "invoices new renders skeleton loader and wraps content with noscript fallback" do
    get new_invoice_path
    assert_response :success

    assert_select "#invoice_form_skeleton" do
      assert_select ".invoice-form-skeleton"
      assert_select ".skeleton-table"
    end

    assert_select "#invoice_form_content[style*='display: none']" do
      assert_select "#invoice-form"
    end

    assert_select "noscript" do
      assert_match(/#invoice_form_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#invoice_form_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "subscriptions index renders skeleton loader and wraps content with noscript fallback" do
    get subscriptions_path
    assert_response :success

    assert_select "#subscriptions_skeleton" do
      assert_select ".subscriptions-page-skeleton"
      assert_select ".skeleton-table"
    end

    assert_select "#subscriptions_content[style*='display: none']" do
      assert_select "#subscriptionTypeTabs"
    end

    assert_select "noscript" do
      assert_match(/#subscriptions_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#subscriptions_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "locations index renders skeleton loader and wraps content with noscript fallback" do
    get locations_path
    assert_response :success

    assert_select "#locations_skeleton" do
      assert_select ".locations-page-skeleton"
      assert_select ".skeleton-table"
    end

    assert_select "#locations_content[style*='display: none']" do
      assert_select "#location-table"
    end

    assert_select "noscript" do
      assert_match(/#locations_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#locations_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "networks index renders skeleton loader and wraps content with noscript fallback" do
    get networks_path
    assert_response :success

    assert_select "#networks_skeleton" do
      assert_select ".networks-page-skeleton"
      assert_select ".network-cards-grid"
    end

    assert_select "#networks_content[style*='display: none']" do
      assert_select "#network_search_form"
    end

    assert_select "noscript" do
      assert_match(/#networks_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#networks_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "companies index renders skeleton loader and wraps content with noscript fallback" do
    get companies_path
    assert_response :success

    assert_select "#companies_skeleton" do
      assert_select ".companies-page-skeleton"
    end

    assert_select "#companies_content[style*='display: none']" do
      assert_select "#company-form"
    end

    assert_select "noscript" do
      assert_match(/#companies_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#companies_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "companies show renders skeleton loader and wraps content with noscript fallback" do
    get company_path(@company)
    assert_response :success

    assert_select "#company_show_skeleton" do
      assert_select ".company-show-skeleton"
    end

    assert_select "#company_show_content[style*='display: none']" do
      assert_select ".company-hero-card"
    end

    assert_select "noscript" do
      assert_match(/#company_show_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#company_show_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "profile edit renders skeleton loader and wraps content with noscript fallback" do
    get edit_profile_path
    assert_response :success

    assert_select "#profile_skeleton" do
      assert_select ".profile-edit-skeleton"
    end

    assert_select "#profile_content[style*='display: none']" do
      assert_select "#edit_profile_form"
    end

    assert_select "noscript" do
      assert_match(/#profile_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#profile_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "incoming tax submissions renders skeleton loader and wraps content with noscript fallback" do
    get tax_submissions_path
    assert_response :success

    assert_select "#tax_submissions_index_skeleton" do
      assert_select ".tax-submissions-index-skeleton"
      assert_select ".skeleton-table"
    end

    assert_select "#tax_submissions_index_content[style*='display: none']" do
      assert_select "#submissionTabs"
    end

    assert_select "noscript" do
      assert_match(/#tax_submissions_index_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#tax_submissions_index_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "skeleton design system defines light and dark mode tokens and reduced motion support" do
    # Design tokens in skeleton.css and critical.css
    [ @skeleton_css, @critical_css ].each do |css|
      assert_includes css, "--skeleton-base"
      assert_includes css, "--skeleton-highlight"
      assert_includes css, "--skeleton-border"
      assert_includes css, "--skeleton-card-bg"
      assert_includes css, "skeleton-shimmer"
      assert_includes css, "skeletonFadeIn"
      assert_includes css, "prefers-reduced-motion"
    end

    # Dark mode overrides
    assert_match(/\[data-theme="dark"\][^{]*\{[^}]*--skeleton-base/m, @skeleton_css)
    assert_match(/\[data-theme="dark"\][^{]*\{[^}]*--skeleton-highlight/m, @skeleton_css)
  end

  test "javascript components integrate smooth skeleton removal and safety fallbacks" do
    # Skeleton utility
    assert_includes @skeleton_loader_js, "export function hideSkeleton"
    assert_includes @skeleton_loader_js, "export function setupSkeletonSafetyFallback"

    # Dashboard integration
    assert_includes @dashboard_js, "import { hideSkeleton, setupSkeletonSafetyFallback } from './skeleton_loader'"
    assert_includes @dashboard_js, "hideSkeleton('dashboard_skeleton', 'dashboard_content')"
    assert_includes @dashboard_js, "dashboard-fetching-active"

    # Submissions integration
    assert_includes @client_submissions_js, "import { hideSkeleton, setupSkeletonSafetyFallback } from './skeleton_loader'"
    assert_includes @client_submissions_js, "hideSkeleton('tax_submissions_skeleton', 'tax_submissions_content')"

    # Notifications integration
    assert_includes @notifications_controller_js, "import { hideSkeleton } from \"../skeleton_loader\""
    assert_includes @notifications_controller_js, "hideSkeleton(\"notifications_skeleton\", \"notifications_content\")"
  end
end
