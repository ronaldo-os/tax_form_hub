class ErrorsController < ApplicationController
  skip_before_action :custom_auth_redirect

  def not_found
    render status: :not_found
  end
end
