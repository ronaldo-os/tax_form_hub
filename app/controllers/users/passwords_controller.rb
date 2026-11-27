class Users::PasswordsController < Devise::PasswordsController
  def edit
    user = resource_class.with_reset_password_token(params[:reset_password_token].to_s)
    unless user&.reset_password_period_valid?
      flash[:alert] = "Your password reset link has expired or is invalid. Please request a new one."
      redirect_to new_password_path(resource_name)
      return
    end

    super
  end

  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      flash[:alert] = resource.errors.full_messages.join("\n")
      redirect_to new_password_path(resource_name)
    end
  end
end
