class Users::SessionsController < Devise::SessionsController
  def create
    super do |resource|
      cookies[:user_theme] = {
        value: resource.theme.presence || "light",
        expires: 1.year.from_now,
        same_site: :lax,
        path: "/"
      }
    end
  end

  def destroy
    cookies.delete(:user_theme, path: "/")
    # Clear any client-side cached data by setting a header
    response.headers['X-Clear-Cache'] = 'true'
    super
  end
end
