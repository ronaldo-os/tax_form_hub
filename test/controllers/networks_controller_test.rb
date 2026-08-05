require "test_helper"

class NetworksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "network_user_#{Time.now.to_i}_#{rand(1000)}@example.com", password: "Password123!@#Secure", password_confirmation: "Password123!@#Secure")
    @other_company = Company.create!(name: "Acme Corp #{rand(1000)}", industry: "Technology", website: "https://acme.com", user: User.create!(email: "acme_owner_#{Time.now.to_i}_#{rand(1000)}@example.com", password: "Password123!@#Secure"))
    sign_in @user
  end

  test "should get index" do
    get networks_url
    assert_response :success
    assert_select ".networks-page"
  end

  test "should search companies" do
    get networks_url, params: { query: "Acme" }
    assert_response :success
    assert_select "turbo-frame#search_results"
  end

  test "should add company to network" do
    assert_difference("@user.networks.count", 1) do
      post networks_url, params: { company_id: @other_company.id }
    end
    assert_redirected_to networks_path
  end

  test "should remove company from network" do
    network = @user.networks.create!(company: @other_company)
    assert_difference("@user.networks.count", -1) do
      delete network_url(network)
    end
    assert_redirected_to networks_path
  end
end
