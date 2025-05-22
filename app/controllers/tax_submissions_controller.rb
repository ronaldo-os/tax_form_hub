class TaxSubmissionsController < ApplicationController
  def new
    @tax_submission = TaxSubmission.new
  end

  def create
    @tax_submission = TaxSubmission.new(tax_submission_params)
    if @tax_submission.save
      redirect_to new_tax_submission_path, notice: "Submission successful."
    else
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
