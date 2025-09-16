class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

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
      flash.now[:alert] = resource.errors.full_messages.join("<br>").html_safe
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
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      respond_with resource, location: after_update_path_for(resource)
    else
      flash.now[:alert] = resource.errors.full_messages.join("<br>").html_safe
      clean_up_passwords resource
      set_minimum_password_length
      render :edit, status: :unprocessable_entity
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
end
