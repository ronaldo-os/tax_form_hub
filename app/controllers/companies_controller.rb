class CompaniesController < ApplicationController
  before_action :set_company, only: [:update, :show]

  def index
    @companies = current_user.companies
    # Prioritize company matching the id param, or fallback to user's first company
    @company = if params[:id]
                 @companies.find_by(id: params[:id]) || @companies.first
               else
                 @companies.first
               end

    if params[:flash_alert] == "visitor_recommendation"
      flash.now[:alert] = "You are currently in visitor view and can't write a recommendation for your own company"
    end
  end



  def show
  end

  def new
    @company = Company.new
  end

  def create
    @company = current_user.companies.build(company_params)

    if @company.save
      redirect_to companies_path(id: @company.id), notice: 'Company was successfully created.', status: :see_other
    else
      @companies = current_user.companies
      render :index, status: :unprocessable_entity
    end
  end

  def update
    unless @company.user == current_user || current_user.superadmin?
      return redirect_to companies_path, alert: "Not authorized."
    end

    if @company.update(company_params)
      redirect_to companies_path(id: @company.id), notice: "Company profile updated.", status: :see_other
    else
      @companies = current_user.companies
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @company = Company.find(params[:id])
    @company.destroy
    redirect_to companies_path, notice: "Company deleted successfully.", status: :see_other
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(
      :name, :website, :industry, :ownership, :address, :phone,
      :description, :size, :share_capital, :registration_address,
      :email_address, :company_id_type, :company_id_number,
      :tax_id_type, :tax_id_number, :internal_identifier, :gln,
      :profile_image
    )
  end
end