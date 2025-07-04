class CompaniesController < ApplicationController
  before_action :set_company, only: [:update, :show]

  def index
    @companies = current_user.companies
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
      :address_line1,
      :address_line2,
      :zip_code,
      :city,
      :country,
      :company_number,
      :tax_number
    )
  end
end
