class Admin::TaxSubmissionsController < ApplicationController
  before_action :set_submission, only: [:show, :update]

  def index
    @tax_submissions = TaxSubmission.all.order(created_at: :desc)

    if params[:q].present?
      @tax_submissions = @tax_submissions.where("email ILIKE ?", "%#{params[:q]}%")
    end
  end

  def show
  end

  def update
    if @tax_submission.update(tax_submission_params)
      redirect_to admin_tax_submissions_path, notice: "Submission updated."
    else
      render :index, alert: "Failed to update."
    end
  end

  private

  def set_submission
    @tax_submission = TaxSubmission.find_by(id: params[:id])
    unless @tax_submission
      redirect_to admin_tax_submissions_path, alert: "Submission not found."
    end
  end

  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed)
  end
end
