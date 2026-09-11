class Users::ThemesController < ApplicationController
  before_action :authenticate_user!

  def update
    theme = params[:theme].to_s
    theme = "light" unless %w[light dark].include?(theme)

    if current_user.update(theme: theme)
      cookies[:user_theme] = {
        value: theme,
        expires: 1.year.from_now,
        same_site: :lax,
        path: "/"
      }
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
