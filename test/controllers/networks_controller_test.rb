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

  test "renders quick filters bar and card filter metadata for connected companies" do
    @other_company.update!(industry: "Technology", ownership: "Private Limited Company", phone: "+63 917 123 4567", website: "https://acme.com")
    @user.networks.create!(company: @other_company)

    # Create an invoice so @other_company matches "With Invoices"
    Invoice.create!(
      user: @user,
      recipient_company: @other_company,
      invoice_type: "sale",
      invoice_category: "standard",
      invoice_number: "INV-NET-CUST-1",
      status: "sent"
    )

    get networks_url
    assert_response :success

    # General quick filter pills
    assert_select "#network_quick_filters_bar .network-filter-pill[data-filter='all']", count: 1
    assert_select "#network_quick_filters_bar .network-filter-pill[data-filter='recent']", count: 1
    assert_select "#network_quick_filters_bar .network-filter-pill[data-filter='with_invoices']", count: 1
    assert_select "#network_quick_filters_bar .network-filter-pill[data-filter='has_contact']", count: 1
    assert_select "#network_quick_filters_bar .network-filter-pill[data-filter='has_website']", count: 1

    # Search, industry, ownership, and sort controls
    assert_select "#network_connected_search", count: 1
    assert_select "#network_industry_filter option[value='technology']", count: 1
    assert_select "#network_ownership_filter option[value='private limited company']", count: 1
    assert_select "#network_sort_filter", count: 1

    # Card metadata attributes
    assert_select ".network-card-col[data-has-invoices='true'][data-has-contact='true'][data-has-website='true'][data-industry='technology'][data-ownership='private limited company']", count: 1
    assert_select "#network_no_filter_matches", count: 1
  end

  test "searching for an unregistered company shows invite button with prefilled company name" do
    get networks_url, params: { query: "Unregistered Partner LLC" }
    assert_response :success
    assert_select ".network-empty-search-popover .open-invite-company-modal-btn[data-company-name='Unregistered Partner LLC']", count: 1
    assert_select "#inviteCompanyModal form#invite_company_form[action='#{invite_networks_path}']", count: 1
  end

  test "inviting an unregistered company sends invitation email and redirects with notice" do
    Rails.cache.clear
    assert_enqueued_emails 1 do
      post invite_networks_url, params: {
        invite_company: {
          company_name: "New Vendor Corp",
          email: "newvendor@example.com",
          message: "Let's connect for Form 2307 submissions."
        }
      }
    end
    assert_redirected_to networks_path
    assert_includes flash[:notice], "Invitation sent to New Vendor Corp (newvendor@example.com)."
  end

  test "inviting with invalid email or own email is rejected" do
    assert_enqueued_emails 0 do
      post invite_networks_url, params: {
        invite_company: { company_name: "Bad Email Co", email: "not-an-email" }
      }
    end
    assert_redirected_to networks_path
    assert_includes flash[:alert], "valid email"

    assert_enqueued_emails 0 do
      post invite_networks_url, params: {
        invite_company: { company_name: "Self Co", email: @user.email }
      }
    end
    assert_redirected_to networks_path
    assert_includes flash[:alert], "own email"
  end

  test "inviting an already registered company email connects them directly without sending invite email" do
    @other_company.update!(email_address: "contact@acme-registered.com")

    assert_difference("@user.networks.count", 1) do
      assert_enqueued_emails 0 do
        post invite_networks_url, params: {
          invite_company: {
            company_name: @other_company.name,
            email: "contact@acme-registered.com"
          }
        }
      end
    end
    assert_redirected_to networks_path
    assert_includes flash[:notice], "already registered and has been added to your network"
  end

  test "invited recipient signing up via invite token prefills fields and auto-connects companies" do
    inviter_company = Company.create!(name: "Inviter HQ Corp", user: @user)
    @user.update!(company: inviter_company)

    invited_email = "invited_partner_#{Time.now.to_i}@example.com"
    token = Rails.application.message_verifier(:network_company_invite).generate(
      { inviter_id: @user.id, company_name: "Invited Partner Co", email: invited_email },
      expires_in: 14.days,
      purpose: :network_company_invite
    )

    sign_out @user
    get new_user_registration_url(invite_token: token)
    assert_response :success
    assert_select "#network_invite_signup_banner", text: /Inviter HQ Corp/
    assert_select "input[name='user[email]'][value='#{invited_email}']"
    assert_select "input[name='user[company_name]'][value='Invited Partner Co']"
    assert_select "input[name='invite_token'][value='#{token}']"

    post user_registration_url, params: {
      invite_token: token,
      user: {
        email: invited_email,
        company_name: "Invited Partner Co",
        password: "Password123!@#Secure",
        password_confirmation: "Password123!@#Secure"
      }
    }
    assert_response :redirect

    new_user = User.find_by!(email: invited_email)
    new_company = new_user.company
    assert_not_nil new_company
    assert_includes @user.reload.connected_companies, new_company
    assert_includes new_user.reload.connected_companies, inviter_company
  end

  test "networks page provides direct invite via email button and allows inviting with email only" do
    Rails.cache.clear

    get networks_url
    assert_response :success
    assert_select "button#direct_invite_company_btn.open-invite-company-modal-btn", count: 1
    assert_select "#invite_company_name:not([required])", count: 1
    assert_select "#invite_company_email[required]", count: 1

    # Searching an email directly prefills data-company-email
    get networks_url, params: { query: "directvendor@example.com" }
    assert_response :success
    assert_select ".network-empty-search-popover .open-invite-company-modal-btn[data-company-email='directvendor@example.com']", count: 1

    # Submitting email-only invitation works without company_name
    assert_enqueued_emails 1 do
      post invite_networks_url, params: {
        invite_company: {
          email: "directvendor@example.com"
        }
      }
    end
    assert_redirected_to networks_path
    assert_includes flash[:notice], "Invitation sent to directvendor@example.com."
  end

  test "expired network invite token shows expired warning banner and does not auto-connect" do
    inviter_company = Company.create!(name: "Inviter Expiry Corp", user: @user)
    @user.update!(company: inviter_company)

    expired_token = Rails.application.message_verifier(:network_company_invite).generate(
      {
        inviter_id: @user.id,
        company_name: "Expired Partner Co",
        email: "expired_partner@example.com",
        expires_at: 1.hour.ago.iso8601
      },
      expires_in: 7.days,
      purpose: :network_company_invite
    )

    sign_out @user
    get new_user_registration_url(invite_token: expired_token)
    assert_response :success
    assert_select "#network_invite_expired_banner", count: 1
    assert_select "#network_invite_signup_banner", count: 0
    assert_select "input[name='invite_token']", count: 0

    post user_registration_url, params: {
      invite_token: expired_token,
      user: {
        email: "expired_signup_#{Time.now.to_i}@example.com",
        company_name: "Expired Partner Co",
        password: "Password123!@#Secure",
        password_confirmation: "Password123!@#Secure"
      }
    }
    assert_response :redirect

    new_user = User.order(:id).last
    refute_includes @user.reload.connected_companies, new_user.company
  end

  test "reset password edit rejects expired reset tokens and allows valid tokens" do
    sign_out @user
    raw_token = @user.send(:set_reset_password_token)

    # Valid token within 1 hour renders reset password form
    get edit_user_password_url(reset_password_token: raw_token)
    assert_response :success

    # Simulate token older than Devise.reset_password_within (1 hour)
    @user.update_column(:reset_password_sent_at, 2.hours.ago)
    get edit_user_password_url(reset_password_token: raw_token)
    assert_redirected_to new_user_password_path
    assert_includes flash[:alert], "expired or is invalid"
  end
end
