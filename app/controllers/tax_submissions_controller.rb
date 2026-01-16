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

  def create
    invoice = Invoice.find_by(id: tax_submission_params[:invoice_id])
    
    # Identify the target company (Issuer for Purchase, Recipient/MyCompany for Sale)
    target_company = invoice&.sale_from || invoice&.recipient_company
    
    # Merge the correct company_id and sender email into params
    submission_params = tax_submission_params.merge(
      company_id: target_company&.id,
      email: tax_submission_params[:email].presence || current_user.email
    )

    @tax_submission = TaxSubmission.new(submission_params)
    
    if @tax_submission.save
      redirect_to params[:redirect_url].presence || root_path, notice: "Tax documents submitted successfully."
    else
      redirect_back fallback_location: root_path, alert: "Failed to submit tax documents: #{@tax_submission.errors.full_messages.join(', ')}"
    end
  end

  def update
    redirect_target = params[:redirect_url].presence || root_path
    
    if @tax_submission.update(tax_submission_params)
      redirect_to redirect_target, notice: "Submission updated."
    else
      redirect_to redirect_target, alert: "Failed to update."
    end
  end

  private

  def load_submissions
    # Show submissions that are EITHER:
    # 1. Received BY my company ('incoming' - traditional view)
    # 2. Sent FOR an invoice where I am the Recipient (I submitted it to the Vendor)
    
    my_company_ids = current_user.companies.pluck(:id)
    
    # Eager load associations
    scope = TaxSubmission.includes(:company, invoice: [:recipient_company, :user])
                         .with_attached_form_2307
                         .with_attached_deposit_slip
                         
    # Get invoices where I am the recipient
    invoice_ids_where_i_am_recipient = Invoice.where(recipient_company_id: my_company_ids).select(:id)

    @unarchived_submissions = scope.where(company_id: my_company_ids)
                                   .where(archived: [false, nil])
                                   .order(created_at: :desc)
                                   
    @archived_submissions = scope.where(company_id: my_company_ids)
                                 .where(archived: true)
                                 .order(created_at: :desc)
    
    Rails.logger.info "DEBUG: Loaded #{@unarchived_submissions.count} unarchived submissions"
  end

  def set_tax_submission
    # Allow finding submission if:
    # 1. It belongs to one of my companies (Incoming)
    # 2. It belongs to an invoice where I am the recipient (Outgoing)
    
    my_company_ids = current_user.companies.pluck(:id)
    scope = TaxSubmission.all
    invoice_ids_where_i_am_recipient = Invoice.where(recipient_company_id: my_company_ids).select(:id)
    
    @tax_submission = scope.where(company_id: my_company_ids)
                           .find_by(id: params[:id])
    
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
