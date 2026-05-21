class Users::SessionsController < Devise::SessionsController
  def destroy
    # Clear any client-side cached data by setting a header
    response.headers['X-Clear-Cache'] = 'true'
    super
  end
end
