class NetworksController < ApplicationController
  before_action :authenticate_user!
  include HttpCaching

  before_action :disable_cache_headers, only: [:index]

  def index
    @networks = current_user.networks.includes(company: { profile_image_attachment: :blob })
                              .order("companies.name ASC")

    connected_ids = @networks.map(&:company_id)
    if connected_ids.any?
      my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq

      sale_company_ids = Invoice.where(user_id: current_user.id, invoice_type: "sale", recipient_company_id: connected_ids)
                                .distinct
                                .pluck(:recipient_company_id)

      supplier_scope = Invoice.where(invoice_type: "purchase", sale_from_id: connected_ids)
      supplier_scope = if my_company_ids.any?
                         supplier_scope.where("user_id = ? OR recipient_company_id IN (?)", current_user.id, my_company_ids)
                       else
                         supplier_scope.where(user_id: current_user.id)
                       end
      purchase_company_ids = supplier_scope.distinct.pluck(:sale_from_id)

      @with_invoices_company_ids = (sale_company_ids + purchase_company_ids).to_set
      @recent_network_count = @networks.count { |n| n.created_at && n.created_at >= 30.days.ago }
      @has_contact_count = @networks.count { |n| n.company&.phone.present? || n.company&.email_address.present? }
      @has_website_count = @networks.count { |n| n.company&.website.present? }
      @connected_industries = @networks.filter_map { |n| n.company&.industry.presence }.uniq.sort
      @connected_ownerships = @networks.filter_map { |n| n.company&.ownership.presence }.uniq.sort
    else
      @with_invoices_company_ids = Set.new
      @recent_network_count = 0
      @has_contact_count = 0
      @has_website_count = 0
      @connected_industries = []
      @connected_ownerships = []
    end

    if params[:query].present?
      msg = "%#{params[:query]}%"
      existing_ids = current_user.connected_company_ids
      existing_ids += current_user.company_ids

      @search_results = Company.with_attached_profile_image
                               .where("name ILIKE ?", msg)
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
          
          render json: { network: network_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier, :country]), 
                         other: other_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier, :country]) }
        else
          render json: { network: current_user.connected_companies.as_json(methods: [:address, :tax_id_number, :website, :industry, :ownership, :phone, :description, :size, :share_capital, :registration_address, :email_address, :company_id_type, :company_id_number, :tax_id_type, :internal_identifier, :country]), 
                         other: [] }
        end
      end
    end
  end

  def create
    company = Company.find(params[:company_id])
    
    # Security check: prevent adding self (if logic dictates) or already added (db constraint handles it but good to check)
    if current_user.connected_companies.include?(company)
      redirect_to networks_path, status: :see_other, alert: "Company is already in your network."
      return
    end

    if current_user.companies.include?(company)
       redirect_to networks_path, status: :see_other, alert: "You cannot add your own company to your network."
       return
    end

    @network = current_user.networks.build(company: company)

    if @network.save
      redirect_to networks_path, status: :see_other, notice: "#{company.name} added to your network."
    else
      redirect_to networks_path(query: params[:query]), status: :see_other, alert: "Failed to add company."
    end
  end

  def destroy
    @network = current_user.networks.find(params[:id])
    company_name = @network.company.name
    @network.destroy
    redirect_to networks_path, status: :see_other, notice: "#{company_name} removed from your network."
  end
end
