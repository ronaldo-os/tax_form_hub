class TaxSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tax_submission, only: [:show, :update]

  def index
    Rails.logger.info "DEBUG: TaxSubmissionsController#index executing"
    load_submissions
  end

  def home
    Rails.logger.info "DEBUG: TaxSubmissionsController#home executing"
    load_submissions
    @companies = current_user.companies
    @tax_submission = TaxSubmission.new # For the modal form
  end

  def show
    respond_to do |format|
      format.js
      format.html
    end
  end

  def update
    if @tax_submission.update(tax_submission_params)
      redirect_back fallback_location: root_path, notice: "Submission updated."
    else
      redirect_back fallback_location: root_path, alert: "Failed to update."
    end
  end

  private

  def load_submissions
    # Assuming 'incoming' submissions means submissions sent to companies owned by the user.
    company_ids = current_user.companies.pluck(:id)
    
    # Eager load associations
    scope = TaxSubmission.includes(:company, :invoice)
                         .with_attached_form_2307
                         .with_attached_deposit_slip
                         .where(company_id: company_ids)

    @unarchived_submissions = scope.where(archived: [false, nil]).order(created_at: :desc)
    @archived_submissions = scope.where(archived: true).order(created_at: :desc)
    
    Rails.logger.info "DEBUG: Loaded #{@unarchived_submissions.count} unarchived submissions"
  end

  def set_tax_submission
    @tax_submission = TaxSubmission.where(company_id: current_user.companies.pluck(:id)).find_by(id: params[:id])
    
    unless @tax_submission
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Submission not found." }
        format.js   { render js: "alert('Submission not found.');" }
      end
    end
  end

  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed, :archived, :company_id, :invoice_id, :details, :form_2307, deposit_slip: [])
  end
end
