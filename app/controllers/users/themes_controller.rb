class Users::ThemesController < ApplicationController
  before_action :authenticate_user!

  def update
    if current_user.update(theme: params[:theme])
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
