class CompaniesController < ApplicationController
  include HttpCaching

  before_action :set_company, only: [ :update, :show ]
  before_action :authorize_show, only: [ :show ]
  before_action :set_cache_headers, only: [:index, :show]

  def index
    @companies = current_user.companies.with_attached_profile_image
    if @companies.empty?
      redirect_to new_company_path, notice: "Please create your first company."
      return
    end
    # Prioritize company matching the id param, or fallback to user's first company
    @company = if params[:id]
                 @companies.find_by(slug: params[:id]) || @companies.first
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
      redirect_to companies_path(@company), notice: "Company was successfully created.", status: :see_other
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
      redirect_to companies_path(@company), notice: "Company profile updated.", status: :see_other
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

  def authorize_show
    unless current_user.companies.include?(@company) || current_user.connected_companies.include?(@company)
      redirect_to networks_path, alert: "Access denied. You can only view companies in your network."
      nil
    end
  end

  def set_company
    @company = Company.find_by(slug: params[:id])
    unless @company
      redirect_to networks_path, alert: "Company not found."
      nil
    end
  end

  def company_params
    params.require(:company).permit(
      :name, :website, :industry, :ownership, :address, :phone,
      :description, :size, :share_capital, :registration_address,
      :email_address, :company_id_type, :company_id_number,
      :tax_id_type, :tax_id_number, :internal_identifier, :gln,
      :profile_image, :country
    )
  end
end
