require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(
      email: "loc_user_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    @other_user = User.create!(
      email: "loc_other_#{Time.now.to_i}_#{rand(10000)}@example.com",
      password: "Password123!@#Secure",
      password_confirmation: "Password123!@#Secure"
    )
    sign_in @user
  end

  test "should get index with locations and bulk action elements" do
    loc = @user.locations.create!(
      location_type: "Ship From",
      location_name: "Warehouse Alpha",
      country: "United States",
      street: "123 Main St",
      city: "New York"
    )

    get locations_url
    assert_response :success
    assert_select "#location-table"
    assert_select "#bulk_action_bar_location_table"
    assert_select "#header_checkbox_location_table"
    assert_select "input.location-row-checkbox[value='#{loc.id}']"
  end

  test "bulk delete successfully deletes multiple selected locations" do
    loc1 = @user.locations.create!(
      location_type: "Ship From",
      location_name: "Warehouse 1",
      country: "United States",
      street: "101 First Ave",
      city: "Chicago"
    )
    loc2 = @user.locations.create!(
      location_type: "Remit To",
      location_name: "Office 2",
      country: "United States",
      street: "202 Second Ave",
      city: "Chicago"
    )
    loc3 = @user.locations.create!(
      location_type: "Tax Representative",
      location_name: "Office 3",
      country: "United States",
      street: "303 Third Ave",
      city: "Chicago"
    )

    assert_difference("@user.locations.count", -2) do
      post bulk_action_locations_url, params: {
        bulk_action: "destroy",
        location_ids: [loc1.id, loc2.id]
      }
    end

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "Successfully deleted 2 locations.", flash[:notice]
    assert_nil Location.find_by(id: loc1.id)
    assert_nil Location.find_by(id: loc2.id)
    assert_not_nil Location.find_by(id: loc3.id)
  end

  test "bulk delete correctly formats singular notice for 1 deleted location" do
    loc = @user.locations.create!(
      location_type: "Ship From",
      location_name: "Single Warehouse",
      country: "United States",
      street: "500 Fifth St",
      city: "Austin"
    )

    assert_difference("@user.locations.count", -1) do
      post bulk_action_locations_url, params: {
        bulk_action: "destroy",
        location_ids: [loc.id]
      }
    end

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "Successfully deleted 1 location.", flash[:notice]
    assert_nil Location.find_by(id: loc.id)
  end

  test "bulk action validates empty selection" do
    post bulk_action_locations_url, params: {
      bulk_action: "destroy",
      location_ids: []
    }

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "No locations selected.", flash[:alert]
  end

  test "bulk action validates invalid action type" do
    loc = @user.locations.create!(
      location_type: "Ship From",
      location_name: "Test Location",
      country: "United States",
      street: "777 Lucky Way",
      city: "Las Vegas"
    )

    assert_no_difference("Location.count") do
      post bulk_action_locations_url, params: {
        bulk_action: "unknown_action",
        location_ids: [loc.id]
      }
    end

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "Invalid action.", flash[:alert]
  end

  test "bulk action enforces tenant isolation and ignores locations of other users" do
    other_loc = @other_user.locations.create!(
      location_type: "Remit To",
      location_name: "Secret Other Location",
      country: "Canada",
      street: "99 Maple St",
      city: "Toronto"
    )

    assert_no_difference("Location.count") do
      post bulk_action_locations_url, params: {
        bulk_action: "destroy",
        location_ids: [other_loc.id]
      }
    end

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "No authorized locations found to perform this action.", flash[:alert]
    assert_not_nil Location.find_by(id: other_loc.id)
  end

  test "bulk delete safely nullifies associated invoice foreign keys" do
    loc = @user.locations.create!(
      location_type: "Ship From",
      location_name: "Shipper Depot",
      country: "United States",
      street: "1 Port Way",
      city: "Seattle"
    )
    company = Company.create!(name: "Partner Co #{rand(1000)}", user: @user)
    invoice = Invoice.create!(
      user: @user,
      recipient_company: company,
      invoice_type: "sale",
      invoice_category: "standard",
      status: "draft",
      ship_from_location_id: loc.id
    )

    assert_difference("@user.locations.count", -1) do
      post bulk_action_locations_url, params: {
        bulk_action: "destroy",
        location_ids: [loc.id]
      }
    end

    assert_response :redirect
    assert_redirected_to locations_path
    assert_equal "Successfully deleted 1 location.", flash[:notice]
    assert_nil Location.find_by(id: loc.id)
    assert_nil invoice.reload.ship_from_location_id
  end

  test "unauthenticated requests are redirected" do
    sign_out @user
    post bulk_action_locations_url, params: {
      bulk_action: "destroy",
      location_ids: [1, 2]
    }
    assert_response :redirect
  end
end
