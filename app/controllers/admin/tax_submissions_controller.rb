class Admin::TaxSubmissionsController < ApplicationController
  def index
    @tax_submissions = TaxSubmission.all.order(created_at: :desc)
    
    if params[:q].present?
      @tax_submissions = @tax_submissions.where("email ILIKE ?", "%#{params[:q]}%")
    end
  end

  def update
    @tax_submission = TaxSubmission.find(params[:id])
    if @tax_submission.update(tax_submission_params)
      redirect_to admin_tax_submissions_path, notice: "Submission updated."
    else
      render :index, alert: "Failed to update."
    end
  end

  private

  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed)
  end
end
