class PagesController < ApplicationController
  def home
    @tax_submissions = TaxSubmission.where(email: current_user.email).order(created_at: :desc) if current_user
    redirect_to admin_tax_submissions_path if current_user&.superadmin?
  end
end
