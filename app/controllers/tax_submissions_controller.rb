class TaxSubmissionsController < ApplicationController
  before_action :set_tax_submission, only: [:destroy, :update]

  def home
    return redirect_to admin_tax_submissions_path if current_user&.superadmin?

    @tax_submission ||= TaxSubmission.new
    prepare_home_data if current_user
  end

  def index
    return redirect_to root_path, alert: "Access denied." unless current_user&.company_id.present?

    scope = TaxSubmission.where(company_id: current_user.company_id)
    @unarchived_submissions = scope.where(archived: [false, nil]).order(created_at: :desc)
    @archived_submissions = scope.where(archived: true).order(created_at: :desc)

    if params[:q].present?
      @unarchived_submissions = @unarchived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
      @archived_submissions = @archived_submissions.where("email ILIKE ?", "%#{params[:q]}%")
    end
  end

  def fetch_invoices
    @invoices = current_user.invoices.where(
      recipient_company_id: params[:company_id],
      status: ["active", "sent", "draft"]
    )
    render json: @invoices.map { |i| { id: i.id, invoice_number: i.invoice_number } }
  end

  def update
    is_owner = current_user.company_id.present? && @tax_submission.company_id == current_user.company_id
    is_submitter = @tax_submission.email == current_user.email

    if (is_owner || is_submitter) && @tax_submission.update(update_params)
      message =
        if update_params.key?(:reviewed) || update_params.key?(:processed)
          generate_status_message
        elsif update_params.key?(:archived)
          @tax_submission.archived? ? "Submission archived." : "Submission unarchived."
        else
          "Submission updated."
        end

      redirect_back fallback_location: root_path, notice: message
    else
      redirect_back fallback_location: root_path, alert: "Update failed or unauthorized."
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
      prepare_home_data if current_user
      flash.now[:alert] = "Submission failed. Please check the form for errors."
      render :home, status: :unprocessable_entity
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

  def prepare_home_data
    @companies = current_user.connected_companies
    @tax_submissions        = TaxSubmission.where(email: current_user.email).order(created_at: :desc)
    @unarchived_submissions = TaxSubmission.where(email: current_user.email, archived: [false, nil]).order(created_at: :desc)
    @archived_submissions   = TaxSubmission.where(email: current_user.email, archived: true).order(created_at: :desc)
  end

  def tax_submission_params
    params.require(:tax_submission).permit(
      :company_id,
      :invoice_id,
      :form_2307,
      { deposit_slip: [] },
      :details
    )
  end

  def update_params
    params.require(:tax_submission).permit(:archived, :reviewed, :processed)
  end

  def set_tax_submission
    @tax_submission = TaxSubmission.find(params[:id])
  end

  def generate_status_message
    if @tax_submission.reviewed? && @tax_submission.processed?
      "Submission marked as reviewed and processed."
    elsif @tax_submission.reviewed?
      "Submission marked as reviewed."
    elsif @tax_submission.processed?
      "Submission marked as processed."
    else
      "Submission status updated."
    end
  end
end