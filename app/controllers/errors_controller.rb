class ErrorsController < ApplicationController
  skip_before_action :custom_auth_redirect

  def not_found
    respond_to do |format|
      format.html { render :not_found, status: :not_found }
      format.json { render json: { error: "Not Found", status: 404 }, status: :not_found }
      format.any  { head :not_found }
    end
  end
end
