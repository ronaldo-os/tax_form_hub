class ApplicationController < ActionController::Base
  before_action :custom_auth_redirect

  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_flash_from_resource_errors, if: :devise_controller?
  allow_browser versions: :modern

  protected

  def custom_auth_redirect
    return if devise_controller?  # allow login/signup pages
    return if user_signed_in?     # allow logged-in users

    if request.path == "/" || request.path == root_path
      # If visiting home page → go to LOGIN
      redirect_to new_user_session_path,
                  alert: "Please sign in to continue."
    else
      # All other pages → go to SIGN UP
      redirect_to new_user_registration_path,
                  alert: "You need to sign up before continuing."
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:company_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:company_name])
  end

  def set_flash_from_resource_errors
    if defined?(resource) && resource&.errors.present?
      flash.now[:alert] = resource.errors.full_messages.join(", ")
    end
  end

  # Logout → login
  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end
end
