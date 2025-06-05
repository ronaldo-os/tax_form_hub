class Admin::TaxSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_superadmin!

  def index
    @tax_submission = TaxSubmission.find_by(id: params[:id])
    @unarchived_submissions = TaxSubmission.where(archived: [false, nil]).order(created_at: :desc)
    @archived_submissions = TaxSubmission.where(archived: true).order(created_at: :desc)

    if params[:q].present?
      @unarchived_submissions = @unarchived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
      @archived_submissions = @archived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
    end
  end

  def show
    @tax_submission = TaxSubmission.find(params[:id])
  end


  def update
    if @tax_submission.update(tax_submission_params)
      message =
        if tax_submission_params.key?(:reviewed)
          @tax_submission.reviewed? ? "Submission marked as reviewed." : "Submission unmarked as reviewed."
        elsif tax_submission_params.key?(:processed)
          @tax_submission.processed? ? "Submission marked as processed." : "Submission unmarked as processed."
        elsif tax_submission_params.key?(:archived)
          @tax_submission.archived? ? "Submission archived." : "Submission unarchived."
        else
          "Submission updated."
        end

      redirect_to admin_tax_submissions_path, notice: message
    else
      redirect_to admin_tax_submissions_path, alert: "Failed to update."
    end
  end

  private

  def authorize_superadmin!
    unless current_user&.role == 'superadmin'
      redirect_to root_path, alert: "Access denied. Superadmin privileges required."
    end
  end

  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed, :archived)
  end

end
