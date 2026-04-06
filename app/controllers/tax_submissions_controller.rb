class TaxSubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_tax_submission, only: [ :show, :update ]

  def index
    Rails.logger.info "DEBUG: TaxSubmissionsController#index executing"
    load_incoming_submissions
    fresh_when etag: @unarchived_submissions, last_modified: @unarchived_submissions.maximum(:updated_at)
  end

  def home
    Rails.logger.info "DEBUG: TaxSubmissionsController#home executing"
    load_sent_submissions
    @companies = companies_with_approved_invoices
    @tax_submission = TaxSubmission.new # For the modal form
    fresh_when etag: @unarchived_submissions, last_modified: @unarchived_submissions.maximum(:updated_at)
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
      @companies = companies_with_approved_invoices
      load_sent_submissions

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
    # For purchase: documents go to the seller (sale_from).
    # For sale: documents go to the customer (recipient_company).
    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq

    if invoice.invoice_type == "purchase"
      target_company = invoice.sale_from || (invoice.user.company if invoice.user && !my_company_ids.include?(invoice.user.company_id)) || invoice.recipient_company
    else
      target_company = invoice.recipient_company
    end

    # Merge the correct company_id and sender email into params
    submission_params = tax_submission_params.merge(
      company_id: target_company&.id,
      email: tax_submission_params[:email].presence || current_user.email
    )

    @tax_submission = TaxSubmission.new(submission_params)

    if @tax_submission.save
      TaxSubmissionMailer.confirmation_email(@tax_submission).deliver_later
      TaxSubmissionMailer.notify_invoice_sender(@tax_submission).deliver_later
      redirect_to params[:redirect_url].presence || root_path, notice: "Tax documents submitted successfully."
    else
      error_message = @tax_submission.errors.full_messages.join(", ")
      @companies = companies_with_approved_invoices
      load_sent_submissions

      respond_to do |format|
        format.html { render :home }
        format.turbo_stream { redirect_back fallback_location: root_path, alert: "Failed to submit tax documents: #{error_message}" }
      end
    end
  end

  def update
    if @tax_submission.update(tax_submission_params)
      notice = "Submission updated."
      redirect_back fallback_location: root_path, notice: notice
    else
      alert = "Failed to update."
      redirect_back fallback_location: root_path, alert: alert
    end
  end

  def fetch_invoices
    company_id = params[:company_id]

    if company_id.blank?
      render json: [], status: :ok
      return
    end

    my_company_ids = current_user.companies.pluck(:id) << current_user.company_id
    my_company_ids = my_company_ids.compact.uniq

    # Find invoices related to the user or their company
    invoices = Invoice.where("user_id = ? OR recipient_company_id IN (?) OR sale_from_id IN (?)", current_user.id, my_company_ids, my_company_ids)
                           .where(status: "approved")
                           .where(archived: [ false, nil ])
                           .where.not(invoice_category: "quote")
                           .where("(invoice_type = 'sale' AND recipient_company_id = :company_id) OR (invoice_type = 'purchase' AND sale_from_id = :company_id)", company_id: company_id)
                           .order(created_at: :desc)

    render json: invoices.map { |inv|
      {
        id: inv.id,
        invoice_number: inv.invoice_number,
        display_name: inv.invoice_number
      }
    }
  end

  private

  def load_incoming_submissions
    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq
    scope = submission_scope

    @unarchived_submissions = scope.where(company_id: my_company_ids)
                                   .where(archived: [ false, nil ])
                                   .order(created_at: :desc)

    @archived_submissions = scope.where(company_id: my_company_ids)
                                 .where(archived: true)
                                 .order(created_at: :desc)
  end

  def load_sent_submissions
    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq
    scope = submission_scope

    # Invoices where I am the creator or my company is the recipient (i.e., I'm the buyer)
    related_invoice_ids = Invoice.where("user_id = ? OR recipient_company_id IN (?) OR sale_from_id IN (?)", current_user.id, my_company_ids, my_company_ids).pluck(:id)

    @unarchived_submissions = scope.where(invoice_id: related_invoice_ids)
                                   .where.not(company_id: my_company_ids) # Focus on what I sent to others
                                   .where(archived: [ false, nil ])
                                   .order(created_at: :desc)

    @archived_submissions = scope.where(invoice_id: related_invoice_ids)
                                 .where.not(company_id: my_company_ids)
                                 .where(archived: true)
                                 .order(created_at: :desc)
  end

  def submission_scope
    TaxSubmission.includes(:company, invoice: [ :recipient_company, :user, :sale_from ])
                 .with_attached_form_2307
                 .with_attached_deposit_slip
  end

  def set_tax_submission
    my_company_ids = current_user.companies.pluck(:id)

    # Identify invoices related to the user (either as creator or where their company is the recipient)
    related_invoice_ids = Invoice.where("user_id = ? OR recipient_company_id IN (?)",
                                        current_user.id,
                                        my_company_ids).select(:id)

    # Allow finding if:
    # 1. It belongs to one of my companies (Incoming)
    # 2. It belongs to an invoice I'm involved in (Outgoing)
    @tax_submission = TaxSubmission.where("company_id IN (?) OR invoice_id IN (?)",
                                          my_company_ids,
                                          related_invoice_ids)
                                   .find_by(id: params[:id])

    unless @tax_submission
      respond_to do |format|
        format.html { redirect_to root_path, alert: "Submission not found." }
        format.js   { render js: "alert('Submission not found.');" }
      end
    end
  end

  def companies_with_approved_invoices
    my_company_ids = current_user.companies.pluck(:id) << current_user.company_id
    my_company_ids = my_company_ids.compact.uniq

    # Find all approved invoices where the user or their company is either the sender or receiver
    invoice_data = Invoice.where("user_id = ? OR recipient_company_id IN (?) OR sale_from_id IN (?)", current_user.id, my_company_ids, my_company_ids)
                                .where(status: "approved")
                                .where(invoice_category: [ "standard", "credit_note" ])
                                .where("archived IS NULL OR archived = ?", false)
                                .pluck(:invoice_type, :recipient_company_id, :sale_from_id)

    target_company_ids = invoice_data.map do |type, recipient_id, sale_from_id|
      # If the user's company is involved, identify the *other* party
      if my_company_ids.include?(recipient_id) && my_company_ids.include?(sale_from_id)
        # Both sides are ours? (Internal transaction). This is rare.
        # Just pick the other party from the POV of the invoice owner or type.
        type == "sale" ? recipient_id : sale_from_id
      elsif my_company_ids.include?(recipient_id)
        # We are the buyer/recipient, target is the sender
        sale_from_id
      elsif my_company_ids.include?(sale_from_id)
        # We are the sender/sale_from, target is the recipient
        recipient_id
      else
        # Fallback to previous logic if not explicitly in our company list
        type == "sale" ? recipient_id : sale_from_id
      end
    end.compact.uniq

    # Return the identified companies directly, avoiding restrictive connected_companies filter
    Company.where(id: target_company_ids)
  end

  def tax_submission_params
    params.require(:tax_submission).permit(:reviewed, :processed, :archived, :company_id, :invoice_id, :details, :email, :form_2307, deposit_slip: [])
  end
end
