require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.create!(
      email: "owner_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @owner_company = Company.create!(
      name: "Owner Corp #{rand(1000)}",
      industry: "Technology",
      website: "https://ownercorp.example.com",
      user: @owner
    )
    @owner.update_column(:company_id, @owner_company.id)

    @visitor = User.create!(
      email: "visitor_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @visitor_company = Company.create!(
      name: "Visitor Co #{rand(1000)}",
      industry: "Consulting",
      website: "https://visitorco.example.com",
      user: @visitor
    )
    @visitor.update_column(:company_id, @visitor_company.id)

    # Visitor connects to owner's company in network
    @visitor.networks.create!(company: @owner_company)

    @admin = User.create!(
      email: "admin_#{Time.now.to_i}_#{rand(1000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure",
      role: "superadmin"
    )
    @admin_company = Company.create!(
      name: "Admin Corp #{rand(1000)}",
      industry: "Administration",
      website: "https://admincorp.example.com",
      user: @admin
    )
    @admin.update_column(:company_id, @admin_company.id)
    # Admin connects to owner's company in network
    @admin.networks.create!(company: @owner_company)
  end

  test "connected company visitor does not see Edit Profile button on company profile" do
    sign_in @visitor
    get company_url(@owner_company)

    assert_response :success
    assert_select "a[href=?]", companies_path(id: @owner_company.slug), count: 0
    assert_no_match "Edit Profile", response.body
    assert_select "#visitor-note", count: 0
  end

  test "superadmin connected to company does not see Edit Profile button on company profile" do
    sign_in @admin
    get company_url(@owner_company)

    assert_response :success
    assert_select "a[href=?]", companies_path(id: @owner_company.slug), count: 0
    assert_no_match "Edit Profile", response.body
    assert_select "#visitor-note", count: 0
  end

  test "company owner sees Edit Profile button and visitor note on their company profile" do
    sign_in @owner
    get company_url(@owner_company)

    assert_response :success
    assert_select "a[href=?]", companies_path(id: @owner_company.slug)
    assert_match "Edit Profile", response.body
    assert_select "#visitor-note", count: 1
  end

  test "company owner sees easily visible Back and Save Changes buttons on company profile edit page" do
    sign_in @owner
    get companies_url

    assert_response :success
    assert_select ".companies-header-bar" do
      assert_select "a.btn-back", text: /Back/
      assert_select "button[type=submit]", text: /Save Changes/
      assert_select "a", text: /View As Visitor/
    end

    assert_select "#update-company-btn", text: /Save Changes/
    assert_select "a.btn-back", count: 2
  end

  test "visitor cannot access edit page for a connected company via companies index params" do
    sign_in @visitor
    get companies_url(id: @owner_company.slug)

    assert_redirected_to company_path(@owner_company)
    follow_redirect!
    assert_match "Not authorized. Only the company owner can edit this profile.", flash[:alert]
  end

  test "superadmin cannot access edit page for another company via companies index params" do
    sign_in @admin
    get companies_url(id: @owner_company.slug)

    assert_redirected_to company_path(@owner_company)
    follow_redirect!
    assert_match "Not authorized. Only the company owner can edit this profile.", flash[:alert]
  end

  test "visitor cannot access edit route for another company" do
    sign_in @visitor
    get edit_company_url(@owner_company)

    assert_redirected_to company_path(@owner_company)
    follow_redirect!
    assert_match "Not authorized. Only the company owner can edit this profile.", flash[:alert]
  end

  test "owner can access edit route and is redirected to company edit profile" do
    sign_in @owner
    get edit_company_url(@owner_company)

    assert_redirected_to companies_path(id: @owner_company.slug)
  end

  test "visitor cannot update another company profile" do
    sign_in @visitor
    patch company_url(@owner_company), params: { company: { name: "Hacked Corp" } }

    assert_redirected_to company_path(@owner_company)
    assert_equal "Not authorized. Only the company owner can edit this profile.", flash[:alert]
    assert_not_equal "Hacked Corp", @owner_company.reload.name
  end

  test "superadmin cannot update another company profile" do
    sign_in @admin
    patch company_url(@owner_company), params: { company: { name: "Admin Edited Corp" } }

    assert_redirected_to company_path(@owner_company)
    assert_equal "Not authorized. Only the company owner can edit this profile.", flash[:alert]
    assert_not_equal "Admin Edited Corp", @owner_company.reload.name
  end

  test "owner can update their own company profile" do
    sign_in @owner
    patch company_url(@owner_company), params: { company: { website: "https://newwebsite.example.com" } }

    assert_redirected_to companies_path(id: @owner_company.slug)
    assert_equal "Company profile updated.", flash[:notice]
    assert_equal "https://newwebsite.example.com", @owner_company.reload.website
  end

  test "non-owner cannot delete company" do
    sign_in @visitor
    assert_no_difference("Company.count") do
      delete company_url(@owner_company)
    end

    assert_redirected_to companies_path
    assert_equal "Not authorized. Only the company owner can delete this company.", flash[:alert]
  end

  test "owner cannot submit recommendation for their own company" do
    sign_in @owner
    assert_no_difference("Recommendation.count") do
      post company_recommendations_url(@owner_company), params: { recommendation: { text: "Self praise" } }
    end

    assert_redirected_to @owner_company
    assert_equal "You cannot write a recommendation for your own company.", flash[:alert]
  end

  test "connected visitor can submit recommendation for company" do
    sign_in @visitor
    assert_difference("Recommendation.count", 1) do
      post company_recommendations_url(@owner_company), params: { recommendation: { text: "Great business partner!" } }
    end

    assert_redirected_to @owner_company
    assert_equal "Recommendation submitted successfully.", flash[:notice]
  end
end
