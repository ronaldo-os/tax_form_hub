class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_flash_from_resource_errors, if: :devise_controller?
  allow_browser versions: :modern

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:company_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:company_name])
  end

  def set_flash_from_resource_errors
    if defined?(resource) && resource&.errors.present?
      flash.now[:alert] = resource.errors.full_messages.join(", ")
    end
  end
end
