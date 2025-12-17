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

    respond_to do |format|
      format.html
      format.json do
        if params[:query].present?
          msg = "%#{params[:query]}%"
          network_companies = current_user.connected_companies.where("name ILIKE ?", msg)
          
          existing_ids = current_user.connected_company_ids + current_user.company_ids
          other_companies = Company.where("name ILIKE ?", msg).where.not(id: existing_ids).limit(20)
          
          render json: { network: network_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier]), 
                         other: other_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier]) }
        else
          render json: { network: current_user.connected_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier]), 
                         other: [] }
        end
      end
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
