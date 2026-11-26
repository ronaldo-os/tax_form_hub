class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]
  before_action :store_profile_back_url, only: [:edit]

  def new
    @invite_payload = verify_network_invite_token(params[:invite_token])
    if @invite_payload.present?
      @inviter = User.find_by(id: @invite_payload["inviter_id"])
      @inviter_company_name = @inviter&.company&.name.presence || @inviter&.companies&.first&.name.presence || @inviter&.display_name
    end

    build_resource({})
    if @invite_payload.present?
      resource.email = @invite_payload["email"] if resource.email.blank?
      resource.company_name = @invite_payload["company_name"] if resource.company_name.blank?
    end
    yield resource if block_given?
    respond_with resource
  end

  def edit
    super
  end

  def create
    build_resource(sign_up_params)
    resource.save

    if resource.persisted?
      created_company = nil
      if params[:user][:company_name].present?
        created_company = resource.companies.create(name: params[:user][:company_name])
        resource.update_column(:company_id, created_company.id) if created_company.persisted?
      end

      connect_invited_companies!(resource, created_company, params[:invite_token])

      if resource.active_for_authentication?
        flash[:notice] = find_message(:signed_up)
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        expire_data_after_sign_in!
        flash[:notice] = find_message(:signed_up_but_inactive)
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      @invite_payload = verify_network_invite_token(params[:invite_token])
      if @invite_payload.present?
        @inviter = User.find_by(id: @invite_payload["inviter_id"])
        @inviter_company_name = @inviter&.company&.name.presence || @inviter&.companies&.first&.name.presence || @inviter&.display_name
      end
      flash.now[:alert] = resource.errors.full_messages.join("\n")
      clean_up_passwords resource
      set_minimum_password_length
      render :new, status: :unprocessable_entity
    end
  end

  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    resource_updated = update_resource(resource, account_update_params)
    yield resource if block_given?

    if resource_updated
      # Only show success message if some change was actually saved (attribute changes or a new profile image)
      if resource.saved_changes.any? || (account_update_params[:profile_image].present?)
        set_flash_message_for_update(resource, prev_unconfirmed_email)
      else
        flash[:notice] = "No changes were made."
      end
      
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      respond_with resource, location: after_update_path_for(resource)
    else
      flash.now[:alert] = resource.errors.full_messages.join("\n")
      clean_up_passwords resource
      set_minimum_password_length
      render :edit, status: :unprocessable_entity
    end
  end

  protected
  
  def update_resource(resource, params)
    if params[:password].present? || params[:password_confirmation].present?
      resource.update_with_password(params)
    else
      clean_params = params.dup
      clean_params.delete(:current_password)
      clean_params.delete(:password) if clean_params[:password].blank?
      clean_params.delete(:password_confirmation) if clean_params[:password_confirmation].blank?
      resource.currency = clean_params[:currency] if clean_params[:currency].present?
      resource.update_without_password(clean_params)
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :email, :profile_image, :password,
      :password_confirmation, :company_name, :currency
    ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :email, :profile_image, :password,
      :password_confirmation, :current_password, :company_name, :currency
    ])
  end

  def after_update_path_for(resource)
    edit_profile_path
  end

  private

  def store_profile_back_url
    return if request.referrer.blank?

    referrer_path = URI.parse(request.referrer).path rescue nil
    return if referrer_path == edit_profile_path || referrer_path == edit_user_registration_path

    session[:profile_back_url] = request.referrer
  end

  def verify_network_invite_token(token)
    return nil if token.blank?

    payload = Rails.application.message_verifier(:network_company_invite).verify(
      token.to_s,
      purpose: :network_company_invite
    )
    payload.is_a?(Hash) ? payload.stringify_keys : nil
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage, StandardError
    nil
  end

  def connect_invited_companies!(new_user, new_company, token)
    payload = verify_network_invite_token(token)
    return if payload.blank?

    inviter = User.find_by(id: payload["inviter_id"])
    return unless inviter && inviter.id != new_user.id

    if new_company&.persisted? && !inviter.companies.include?(new_company)
      inviter.networks.find_or_create_by(company: new_company)
    end

    inviter_company = inviter.company || inviter.companies.first
    if inviter_company&.persisted? && !new_user.companies.include?(inviter_company)
      new_user.networks.find_or_create_by(company: inviter_company)
    end
  rescue StandardError => e
    Rails.logger.error "[Users::RegistrationsController#connect_invited_companies!] #{e.class}: #{e.message}"
  end
end