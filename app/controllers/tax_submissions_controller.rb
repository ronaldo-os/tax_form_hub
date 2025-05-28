class TaxSubmissionsController < ApplicationController
  def new
    @tax_submission = TaxSubmission.new
  end

  def create
    @tax_submission = TaxSubmission.new(tax_submission_params)
    if @tax_submission.save
      # Send confirmation email to the current user if they have an email
      if current_user&.email.present?
        TaxSubmissionMailer.confirmation_email(current_user, @tax_submission).deliver_later
      end

      # Send confirmation email to recipient included by the user
      TaxSubmissionMailer.confirmation_email(@tax_submission).deliver_later if @tax_submission.email.present?

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
      :email,
      :form_2307,
      :deposit_slip,
      :details
    )
  end
end
