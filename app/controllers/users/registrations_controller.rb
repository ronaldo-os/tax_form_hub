class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]
  before_action :configure_account_update_params, only: [:update]

  def create
    super do |resource|
      Rails.logger.info "📝 SIGNUP PARAMS: #{params[:user].inspect}"

      if resource.persisted? && params[:user][:company_name].present?
        company = resource.companies.create(name: params[:user][:company_name]) # ✅ uses association
        if company.persisted?
          resource.update_column(:company_id, company.id)
          Rails.logger.info "✅ Assigned company ##{company.id} to user ##{resource.id}"
        else
          Rails.logger.warn "❌ Failed to create company: #{company.errors.full_messages}"
        end
      end
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
