class TaxSubmissionsController < ApplicationController
  def new
    @tax_submission = TaxSubmission.new
  end

  def create
    @tax_submission = TaxSubmission.new(tax_submission_params)
    # Automatically assign the current user's email only
    @tax_submission.email = current_user.email if current_user

    if @tax_submission.save
      TaxSubmissionMailer.confirmation_email(current_user, @tax_submission).deliver_later

      # Notify all superadmins
      TaxSubmissionMailer.notify_superadmins(@tax_submission).deliver_later

      redirect_to root_path, notice: "Submission successful."
    else
      flash.now[:alert] = "Submission failed. Please check the form for errors."
      render :new, status: :unprocessable_entity
    end
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
end
