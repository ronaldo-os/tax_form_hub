class PagesController < ApplicationController
  def home
    if current_user&.superadmin?
      redirect_to admin_tax_submissions_path
    else
      render :home
    end
  end
end
