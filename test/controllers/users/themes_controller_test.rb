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
end
