class Admin::TaxSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_superadmin!
  before_action :set_tax_submission, only: [:show, :update]


  def index
    @unarchived_submissions = TaxSubmission.where(archived: [false, nil]).order(created_at: :desc)
    @archived_submissions = TaxSubmission.where(archived: true).order(created_at: :desc)

    if params[:q].present?
      @unarchived_submissions = @unarchived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
      @archived_submissions = @archived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
    end
  end

  def show
    @tax_submission = TaxSubmission.find(params[:id])

    respond_to do |format|
      format.js
      format.html
    end
  end

  def update
    if @tax_submission.update(tax_submission_params)
      message =
        if tax_submission_params.key?(:reviewed) && tax_submission_params.key?(:processed)
          if @tax_submission.reviewed? && @tax_submission.processed?
            "Submission marked as reviewed and processed."
          elsif @tax_submission.reviewed?
            "Submission marked as reviewed. Processed status unchanged."
          elsif @tax_submission.processed?
            "Submission marked as processed. Reviewed status unchanged."
          else
            "Submission unmarked as reviewed and processed."
          end
        elsif tax_submission_params.key?(:reviewed)
          @tax_submission.reviewed? ? "Submission marked as reviewed." : "Submission unmarked as reviewed."
        elsif tax_submission_params.key?(:processed)
          @tax_submission.processed? ? "Submission marked as processed." : "Submission unmarked as processed."
        elsif tax_submission_params.key?(:archived)
          @tax_submission.archived? ? "Submission archived." : "Submission unarchived."
        else
          "Submission updated."
        end

      TaxSubmissionMailer.status_updated(@tax_submission, message).deliver_later
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

  def set_tax_submission
    @tax_submission = TaxSubmission.find_by(id: params[:id])

    unless @tax_submission
      respond_to do |format|
        format.html { redirect_to admin_tax_submissions_path, alert: "Submission not found." }
        format.js   { render js: "alert('Submission not found.');" }
      end
    end
  end


  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed, :archived)
  end
end
