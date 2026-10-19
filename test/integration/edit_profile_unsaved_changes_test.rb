require "test_helper"

class EditProfileUnsavedChangesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "profile_test_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      currency: "PHP"
    )
    @company = Company.create!(name: "Profile Corp", user: @user)
    @user.update(company: @company)
  end

  test "edit profile page renders all editable fields required for unsaved change detection" do
    sign_in @user
    get edit_profile_path
    assert_response :success

    # Form with explicit ID
    assert_select "form#edit_profile_form"

    # 1. Avatar field
    assert_select "input#profile_image_input[type='file']"

    # 2. Email Address field with baseline data-initial-value
    assert_select "input#user_email[type='email'][data-initial-value=?]", @user.email

    # 3. Preferred Dashboard Currency with baseline data-initial-value
    assert_select "select#user_currency_select[data-initial-value=?]", "PHP"

    # 4. New Password
    assert_select "input#password[type='password']"

    # 5. Confirm New Password
    assert_select "input#password_confirmation[type='password']"

    # 6. Current Password with autocomplete new-password
    assert_select "input#current_password[type='password'][autocomplete='new-password']"

    # Back button
    assert_select "a[data-behavior='back-button']"

    # Submit button
    assert_select "button#update-profile-btn[type='submit']"
  end

  test "edit profile page includes turbo-cache-control no-cache to prevent dirty cache retention" do
    sign_in @user
    get edit_profile_path
    assert_response :success
    assert_select "head meta[name='turbo-cache-control'][content='no-cache']"
  end

  test "saving profile successfully updates fields and redirects back to edit_profile_path" do
    sign_in @user
    new_email = "updated_#{Time.now.to_i}@example.com"
    put profile_path, params: {
      user: {
        email: new_email,
        currency: "USD"
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal new_email, @user.reload.email
    assert_equal "USD", @user.currency
  end
end
