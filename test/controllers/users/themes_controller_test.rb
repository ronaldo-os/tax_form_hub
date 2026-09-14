require "test_helper"

class Users::ThemesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "theme_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      theme: "light"
    )
    @company = Company.create!(name: "Theme Test Corp #{Time.now.to_i}", user: @user)
    @user.update(company: @company)
  end

  test "requires authentication to update theme" do
    patch update_theme_path, params: { theme: "dark" }, as: :json
    assert_redirected_to new_user_registration_path
  end

  test "updates user theme and sets user_theme cookie" do
    sign_in @user

    patch update_theme_path, params: { theme: "dark" }, as: :json
    assert_response :ok

    assert_equal "dark", @user.reload.theme
    assert_equal "dark", cookies[:user_theme]

    # Switch back to light
    patch update_theme_path, params: { theme: "light" }, as: :json
    assert_response :ok

    assert_equal "light", @user.reload.theme
    assert_equal "light", cookies[:user_theme]
  end

  test "falls back to light when invalid theme passed" do
    sign_in @user

    patch update_theme_path, params: { theme: "malicious_script" }, as: :json
    assert_response :ok

    assert_equal "light", @user.reload.theme
    assert_equal "light", cookies[:user_theme]
  end

  test "layout renders active theme from cookies" do
    sign_in @user

    cookies[:user_theme] = "dark"
    get dashboard_path
    assert_response :success

    assert_select "html[data-theme='dark']"
    assert_select "html[data-bs-theme='dark']"
    assert_select "meta[name='user-theme'][content='dark']"
    assert_includes response.body, "Light Mode"
  end

  test "layout falls back to user theme when cookie is empty" do
    @user.update(theme: "dark")
    sign_in @user

    get dashboard_path
    assert_response :success

    assert_select "html[data-theme='dark']"
    assert_select "html[data-bs-theme='dark']"
    assert_select "meta[name='user-theme'][content='dark']"
  end

  test "login page always displays default light theme regardless of cookie" do
    cookies[:user_theme] = "dark"
    get new_user_session_path
    assert_response :success

    assert_select "html[data-theme='light']"
    assert_select "html[data-bs-theme='light']"
    assert_select "meta[name='user-theme'][content='light']"
  end

  test "logging out clears user_theme cookie and redirects to login in light theme" do
    sign_in @user
    cookies[:user_theme] = "dark"

    delete destroy_user_session_path
    assert_redirected_to new_user_session_path
    assert cookies[:user_theme].blank?

    follow_redirect!
    assert_response :success
    assert_select "html[data-theme='light']"
    assert_select "html[data-bs-theme='light']"
    assert_select "meta[name='user-theme'][content='light']"
  end

  test "logging in sets user_theme cookie to user's saved theme" do
    @user.update(theme: "dark")

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "Password123!@#Secure"
      }
    }
    assert_redirected_to root_path
    assert_equal "dark", cookies[:user_theme]

    follow_redirect!
    assert_response :success
    assert_select "html[data-theme='dark']"
    assert_select "html[data-bs-theme='dark']"
    assert_select "meta[name='user-theme'][content='dark']"
  end

  test "different users on the same browser do not share or leak theme preferences" do
    user_b = User.create!(
      email: "theme_user_b_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      theme: "light"
    )

    # User A logs in and sets dark theme
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "Password123!@#Secure"
      }
    }
    patch update_theme_path, params: { theme: "dark" }, as: :json
    assert_equal "dark", cookies[:user_theme]

    # User A logs out
    delete destroy_user_session_path
    assert cookies[:user_theme].blank?

    # User B logs in on same browser
    post user_session_path, params: {
      user: {
        email: user_b.email,
        password: "Password123!@#Secure"
      }
    }
    assert_equal "light", cookies[:user_theme]

    follow_redirect!
    assert_response :success
    assert_select "html[data-theme='light']"
    assert_select "html[data-bs-theme='light']"
    assert_select "meta[name='user-theme'][content='light']"
  end

  test "user saved theme preference is applied consistently on a new session or browser" do
    @user.update(theme: "dark")

    # Simulate a new browser session with empty cookies and no prior state
    cookies.delete(:user_theme)

    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "Password123!@#Secure"
      }
    }
    assert_equal "dark", cookies[:user_theme]

    follow_redirect!
    assert_response :success
    assert_select "html[data-theme='dark']"
    assert_select "html[data-bs-theme='dark']"
    assert_select "meta[name='user-theme'][content='dark']"
  end
end
