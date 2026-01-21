class TaxSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tax_submission, only: [:show, :update]

  def index
    Rails.logger.info "DEBUG: TaxSubmissionsController#index executing"
    load_incoming_submissions
  end

  def home
    Rails.logger.info "DEBUG: TaxSubmissionsController#home executing"
    load_sent_submissions
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
    # Validate invoice selection
    if tax_submission_params[:invoice_id].blank?
      @tax_submission = TaxSubmission.new(tax_submission_params)
      @tax_submission.errors.add(:invoice_id, "must be selected")
      @companies = current_user.companies
      load_submissions
      
      respond_to do |format|
        format.html { render :home }
        format.turbo_stream { redirect_back fallback_location: root_path, alert: "Please select an invoice number." }
      end
      return
    end
    
    invoice = Invoice.find_by(id: tax_submission_params[:invoice_id])
    
    unless invoice
      redirect_back fallback_location: root_path, alert: "The selected invoice could not be found. Please try again."
      return
    end
    
    # Identify the target company (Vendor for Purchase, Customer for Sale)
    # For purchase: documents go to the seller (sale_from). If nil (manual), we try recipient_company.
    # For sale: documents go to the customer (recipient_company).
    target_company = invoice.invoice_type == 'purchase' ? (invoice.sale_from || invoice.recipient_company) : invoice.recipient_company
    
    # Merge the correct company_id and sender email into params
    submission_params = tax_submission_params.merge(
      company_id: target_company&.id,
      email: tax_submission_params[:email].presence || current_user.email
    )

    @tax_submission = TaxSubmission.new(submission_params)
    
    if @tax_submission.save
      redirect_to params[:redirect_url].presence || root_path, notice: "Tax documents submitted successfully."
    else
      error_message = @tax_submission.errors.full_messages.join(', ')
      @companies = current_user.companies
      load_submissions
      
      respond_to do |format|
        format.html { render :home }
        format.turbo_stream { redirect_back fallback_location: root_path, alert: "Failed to submit tax documents: #{error_message}" }
      end
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

  def fetch_invoices
    company_id = params[:company_id]
    
    if company_id.blank?
      render json: [], status: :ok
      return
    end
    
    # Find invoices where the selected company is involved
    # For tax submissions, we want invoices where:
    # 1. The company is the issuer (sale_from) - for purchase invoices
    # 2. The company is the recipient - for sale invoices created by current user
    invoices = Invoice.where(
      "(sale_from_id = ? OR (recipient_company_id = ? AND user_id = ?))",
      company_id,
      company_id,
      current_user.id
    ).where(archived: [false, nil])
     .order(created_at: :desc)
     .select(:id, :invoice_number, :invoice_type, :created_at)
    
    render json: invoices.map { |inv| 
      { 
        id: inv.id, 
        invoice_number: inv.invoice_number,
        invoice_type: inv.invoice_type
      } 
    }
  end

  private

  def load_incoming_submissions
    my_company_ids = current_user.companies.pluck(:id)
    scope = submission_scope
    
    @unarchived_submissions = scope.where(company_id: my_company_ids)
                                   .where(archived: [false, nil])
                                   .order(created_at: :desc)
                                   
    @archived_submissions = scope.where(company_id: my_company_ids)
                                 .where(archived: true)
                                 .order(created_at: :desc)
  end

  def load_sent_submissions
    my_company_ids = current_user.companies.pluck(:id)
    scope = submission_scope
    
    # Invoices where I am the creator or my company is the recipient (i.e., I'm the buyer)
    related_invoice_ids = Invoice.where("user_id = ? OR recipient_company_id IN (?)", current_user.id, my_company_ids).pluck(:id)

    @unarchived_submissions = scope.where(invoice_id: related_invoice_ids)
                                   .where.not(company_id: my_company_ids) # Focus on what I sent to others
                                   .where(archived: [false, nil])
                                   .order(created_at: :desc)
                                   
    @archived_submissions = scope.where(invoice_id: related_invoice_ids)
                                 .where.not(company_id: my_company_ids)
                                 .where(archived: true)
                                 .order(created_at: :desc)
  end

  def submission_scope
    TaxSubmission.includes(:company, invoice: [:recipient_company, :user, :sale_from])
                 .with_attached_form_2307
                 .with_attached_deposit_slip
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
    params.require(:tax_submission).permit(:reviewed, :processed, :archived, :company_id, :invoice_id, :details, :email, :form_2307, deposit_slip: [])
  end
end
