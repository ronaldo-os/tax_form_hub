class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  protected

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update) do |user_params|
      user_params.permit(:email, :company_name, :password, :password_confirmation, :current_password)
    end
  end
end
