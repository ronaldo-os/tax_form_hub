class TaxSubmissionsController < ApplicationController
  before_action :set_tax_submission, only: [:destroy, :update]

  def home
    return redirect_to admin_tax_submissions_path if current_user&.superadmin?

    @tax_submission = TaxSubmission.new
    if current_user
      @tax_submissions        = TaxSubmission.where(email: current_user.email).order(created_at: :desc)
      @unarchived_submissions = TaxSubmission.where(email: current_user.email, archived: [false, nil]).order(created_at: :desc)
      @archived_submissions   = TaxSubmission.where(email: current_user.email, archived: true).order(created_at: :desc)
    end
  end

  def update
    if @tax_submission.email == current_user.email && @tax_submission.update(update_params)
      message = if update_params.key?(:archived)
        @tax_submission.archived? ? "Submission archived." : "Submission unarchived."
      else
        "Submission updated."
      end
      redirect_to root_path, notice: message
    else
      redirect_to root_path, alert: "Update failed or unauthorized."
    end
  end

  def new
    @tax_submission = TaxSubmission.new
  end

  def create
    @tax_submission = TaxSubmission.new(tax_submission_params)
    @tax_submission.email = current_user.email if current_user

    if @tax_submission.save
      TaxSubmissionMailer.confirmation_email(@tax_submission).deliver_later
      TaxSubmissionMailer.notify_superadmins(@tax_submission).deliver_later
      redirect_to root_path, notice: "Submission successful."
    else
      flash.now[:alert] = "Submission failed. Please check the form for errors."
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @tax_submission = TaxSubmission.find(params[:id])
    respond_to do |format|
      format.html
      format.js
    end
  end


  def destroy
    @tax_submission.destroy
    redirect_to root_path, notice: "Submission deleted successfully."
  end

  private

  def tax_submission_params
    params.require(:tax_submission).permit(
      :company_name,
      :form_2307,
      { deposit_slip: [] },
      :details
    )
  end

  def update_params
    params.require(:tax_submission).permit(:archived)
  end

  def set_tax_submission
    @tax_submission = TaxSubmission.find(params[:id])
  end
end