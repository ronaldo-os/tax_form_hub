class NetworksController < ApplicationController
  before_action :authenticate_user!

  def index
    @networks = current_user.networks.includes(:company).order("companies.name ASC")
    
    if params[:query].present?
      msg = "%#{params[:query]}%"
      existing_ids = current_user.connected_company_ids
      existing_ids += current_user.company_ids

      @search_results = Company.where("name ILIKE ?", msg)
                               .where.not(id: existing_ids)
                               .limit(20)
    end
  end

  def create
    company = Company.find(params[:company_id])
    
    # Security check: prevent adding self (if logic dictates) or already added (db constraint handles it but good to check)
    if current_user.connected_companies.include?(company)
      redirect_to networks_path, alert: "Company is already in your network."
      return
    end

    if current_user.companies.include?(company)
       redirect_to networks_path, alert: "You cannot add your own company to your network."
       return
    end

    @network = current_user.networks.build(company: company)

    if @network.save
      redirect_to networks_path, notice: "#{company.name} added to your network."
    else
      redirect_to networks_path(query: params[:query]), alert: "Failed to add company."
    end
  end

  def destroy
    @network = current_user.networks.find(params[:id])
    company_name = @network.company.name
    @network.destroy
    redirect_to networks_path, notice: "#{company_name} removed from your network."
  end
end
