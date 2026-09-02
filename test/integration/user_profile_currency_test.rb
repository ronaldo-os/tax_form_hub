require "test_helper"

class UserProfileCurrencyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "currency_user_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      currency: "PHP"
    )
    @company = Company.create!(name: "Currency Corp", user: @user)
    @user.update(company: @company)
  end

  test "user can view currency option in edit profile page" do
    sign_in @user
    get edit_profile_path
    assert_response :success
    assert_select "select#user_currency_select"
    assert_select "select#user_currency_select option[value='PHP'][selected]"
    assert_select "select#user_currency_select option[value='USD']"
    assert_select "select#user_currency_select option[value='EUR']"
  end

  test "user can change currency on edit profile and it updates default currency on dashboard" do
    sign_in @user
    put user_registration_path, params: {
      user: {
        email: @user.email,
        currency: "USD",
        current_password: "Password123!@#Secure"
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_equal "USD", @user.reload.currency

    # Check dashboard reflects USD
    get dashboards_analytics_data_url(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "USD", json["currency"]
    assert_equal "USD", json["user_currency"]
  end

  test "user can change currency on edit profile without providing current password" do
    sign_in @user
    put user_registration_path, params: {
      user: {
        email: @user.email,
        currency: "EUR"
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_equal "EUR", @user.reload.currency

    # Check edit page now renders EUR selected
    get edit_profile_path
    assert_response :success
    assert_select "select#user_currency_select option[value='EUR'][selected]"

    # Check dashboard reflects EUR
    get dashboards_analytics_data_url(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "EUR", json["currency"]
    assert_equal "EUR", json["user_currency"]
  end
end
