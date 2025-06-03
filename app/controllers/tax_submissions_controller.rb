class TaxSubmissionsController < ApplicationController
  before_action :set_tax_submission, only: [:destroy]

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

  def destroy
    @tax_submission.destroy
    redirect_to root_path, notice: "Submission deleted successfully."
  end

  private

  def tax_submission_params
    params.require(:tax_submission).permit(
      :company_name,
      :form_2307,
      :deposit_slip,
      :details
    )
  end

  def set_tax_submission
    @tax_submission = TaxSubmission.find(params[:id])
  end
end
