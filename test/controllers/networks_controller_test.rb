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

  test "connected company cards display quick actions for invoice, quote, and tax docs" do
    @user.networks.create!(company: @other_company)

    get networks_url
    assert_response :success
    assert_select ".network-company-card .network-quick-actions", count: 1
    assert_select ".network-quick-actions a.btn-network-invoice[href='#{new_invoice_path(recipient_company_id: @other_company.id)}']", count: 1
    assert_select ".network-quick-actions a.btn-network-quote[href='#{new_invoice_path(category: "quote", recipient_company_id: @other_company.id)}']", count: 1
    assert_select ".network-quick-actions a.btn-network-tax[href='#{tax_submissions_home_path(company_id: @other_company.id, open_modal: "true")}']", count: 1
  end

  test "new invoice quick action prefills recipient company" do
    get new_invoice_url, params: { recipient_company_id: @other_company.id }
    assert_response :success
    assert_select "input#recipient_company_id[value='#{@other_company.id}']", count: 1
  end

  test "new quote quick action prefills recipient company" do
    get new_invoice_url, params: { category: "quote", recipient_company_id: @other_company.id }
    assert_response :success
    assert_select "input#recipient_company_id[value='#{@other_company.id}']", count: 1
  end

  test "submit tax docs quick action prefills company and opens modal" do
    get tax_submissions_home_url, params: { company_id: @other_company.id, open_modal: "true" }
    assert_response :success
    assert_select "input#prefill_company_id[value='#{@other_company.id}']", count: 1
    assert_select "input#open_submit_modal[value='true']", count: 1
  end
end
