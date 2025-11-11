class CompaniesController < ApplicationController
  before_action :set_company, only: [:update, :show]

  def index
    @companies = current_user.companies
    @company = current_user.companies.first

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
      redirect_to companies_path, notice: 'Company was successfully created.'
    else
      render :index
    end
  end

  def update
    @company = Company.find(params[:id])
    if @company.update(company_params)
      redirect_to companies_path(@company), notice: "Company profile updated."
    else
      redirect_to companies_path, alert: "Failed to update company."
    end
  end

  def destroy
    @company = Company.find(params[:id])
    @company.destroy
    redirect_to companies_path, notice: "Company deleted successfully."
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