class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]
  before_action :store_profile_back_url, only: [:edit]

  def edit
    super
  end

  def create
    build_resource(sign_up_params)
    resource.save

    if resource.persisted?
      if params[:user][:company_name].present?
        company = resource.companies.create(name: params[:user][:company_name])
        resource.update_column(:company_id, company.id) if company.persisted?
      end

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
    if params[:password].blank? && params[:password_confirmation].blank? && params[:current_password].blank?
      # If all password fields are blank, update other fields like profile_image or email without current password
      resource.update_without_password(params.except(:current_password))
    else
      # If any password field is present, use standard Devise update which requires current_password
      resource.update_with_password(params)
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :email, :profile_image, :password,
      :password_confirmation, :company_name
    ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :email, :profile_image, :password,
      :password_confirmation, :current_password, :company_name
    ])
  end

  def after_update_path_for(resource)
    edit_profile_path
  end

  private

  def store_profile_back_url
    return if request.referrer.blank?
    return if request.referrer.include?(edit_profile_path)

    session[:profile_back_url] = request.referrer
  end
end