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

    # Skeleton placeholder container exists
    assert_select "#dashboard_skeleton" do
      assert_select ".analytics-dashboard-skeleton"
      assert_select ".dashboard-header-card"
      assert_select ".bento-card"
      assert_select ".skeleton-chart-container"
      assert_select ".skeleton-donut"
    end

    # Content container exists with initial hidden state for smooth cross-fade
    assert_select "#dashboard_content[style*='display: none']" do
      assert_select "#performanceTrendChart"
      assert_select "#statusDonutChart"
    end

    # Noscript fallback ensures accessibility without JS
    assert_select "noscript" do
      assert_match(/#dashboard_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#dashboard_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "tax submissions home renders skeleton loader and wraps content with noscript fallback" do
    get tax_submissions_home_path
    assert_response :success

    # Skeleton placeholder container exists
    assert_select "#tax_submissions_skeleton" do
      assert_select ".tax-submissions-skeleton"
      assert_select ".skeleton-table"
      assert_select "thead.table-light"
    end

    # Content container exists with initial hidden state
    assert_select "#tax_submissions_content[style*='display: none']" do
      assert_select "#submissionTabs"
      assert_select "#taxSubmissionsSentActive"
      assert_select "#taxSubmissionsSentArchived"
    end

    # Noscript fallback ensures accessibility without JS
    assert_select "noscript" do
      assert_match(/#tax_submissions_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#tax_submissions_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
    end
  end

  test "notifications page renders skeleton loader and wraps content with noscript fallback" do
    get notifications_path
    assert_response :success

    # Skeleton placeholder container exists
    assert_select "#notifications_skeleton" do
      assert_select ".notifications-skeleton"
      assert_select ".stat-widget-card"
      assert_select ".notification-page-card"
    end

    # Content container exists with initial hidden state
    assert_select "#notifications_content[style*='display: none']" do
      assert_select "#notifications_header_bar"
      assert_select "#notifications_stat_cards"
    end

    # Noscript fallback ensures accessibility without JS
    assert_select "noscript" do
      assert_match(/#notifications_skeleton\s*\{\s*display:\s*none\s*!important;\s*\}/, response.body)
      assert_match(/#notifications_content\s*\{\s*display:\s*block\s*!important;\s*\}/, response.body)
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
