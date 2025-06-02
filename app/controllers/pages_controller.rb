class PagesController < ApplicationController
  def home
    return redirect_to admin_tax_submissions_path if current_user&.superadmin?
    @tax_submissions = TaxSubmission.where(email: current_user.email).order(created_at: :desc) if current_user
    redirect_to admin_tax_submissions_path if current_user&.superadmin?
    if current_user
      @unarchived_submissions = TaxSubmission.where(email: current_user.email, archived: [false, nil]).order(created_at: :desc)
      @archived_submissions   = TaxSubmission.where(email: current_user.email, archived: true).order(created_at: :desc)
    end
  end

  def update
    @submission = TaxSubmission.find(params[:id])
    if @submission.email == current_user.email && @submission.update(tax_submission_params)
      redirect_to root_path, notice: "Submission updated."
    else
      redirect_to root_path, alert: "Update failed or unauthorized."
    end
  end

  private

  def tax_submission_params
    params.require(:tax_submission).permit(:archived)
  end
end
