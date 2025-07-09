class CompaniesController < ApplicationController
  before_action :set_company, only: [:update, :show]

  def index
    @companies = current_user.companies
    @company = current_user.companies.first
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
      redirect_to companies_path, notice: "Company updated successfully."
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
      :name,
      :website,
      :industry,
      :ownership,
      :address,
      :phone,
      :description,
      :size,
      :share_capital,
      :registration_address,
      :email_address,
      :company_id_type,
      :tax_id_type,
      :gln,
      :company_id_number,
      :tax_id_number,
      :internal_identifier
    )
  end
end