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

  INVITE_EMAIL_REGEX = /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/
  MAX_INVITES_PER_HOUR = 10
  INVITE_TOKEN_TTL = NetworkInvitationMailer::INVITE_TOKEN_TTL

  def destroy
    @network = current_user.networks.find(params[:id])
    company_name = @network.company.name
    @network.destroy
    redirect_to networks_path, status: :see_other, notice: "#{company_name} removed from your network."
  end

  def invite
    invite_params = params.fetch(:invite_company, params).permit(:company_name, :email, :message)
    company_name = invite_params[:company_name].to_s.gsub(/[\r\n\t]+/, " ").strip
    email = invite_params[:email].to_s.strip.downcase
    message = invite_params[:message].to_s.strip

    if company_name.length > 150
      redirect_to networks_path, status: :see_other, alert: "Company name must be 150 characters or fewer."
      return
    end

    if email.blank? || email.length > 254 || !email.match?(INVITE_EMAIL_REGEX)
      redirect_to networks_path, status: :see_other, alert: "Please enter a valid email address."
      return
    end

    if message.length > 500
      redirect_to networks_path, status: :see_other, alert: "Personal note must be 500 characters or fewer."
      return
    end

    if email == current_user.email.to_s.downcase
      redirect_to networks_path, status: :see_other, alert: "You cannot invite your own email address."
      return
    end

    # Check if the company or user is already registered on Tax Form Hub
    existing_user = User.find_by("LOWER(email) = ?", email)
    existing_company = Company.find_by("LOWER(email_address) = ?", email) ||
                       existing_user&.company ||
                       existing_user&.companies&.first

    if existing_company.present?
      if current_user.companies.include?(existing_company) || current_user.company_id == existing_company.id
        redirect_to networks_path, status: :see_other, alert: "You cannot invite your own company."
        return
      end

      if current_user.connected_companies.include?(existing_company)
        redirect_to networks_path, status: :see_other, notice: "#{existing_company.name} is already in your network."
        return
      end

      network = current_user.networks.build(company: existing_company)
      if network.save
        redirect_to networks_path, status: :see_other, notice: "#{existing_company.name} is already registered and has been added to your network."
      else
        redirect_to networks_path, status: :see_other, alert: "Unable to connect with #{existing_company.name}."
      end
      return
    end

    # Rate limit invitations per user and per recipient email to prevent email abuse
    user_rate_key = "network_invite_rate:user:#{current_user.id}"
    recipient_rate_key = "network_invite_rate:user:#{current_user.id}:recipient:#{Digest::SHA256.hexdigest(email)}"

    if Rails.cache.read(recipient_rate_key).present?
      redirect_to networks_path, status: :see_other, alert: "An invitation was already sent to #{email} recently. Please wait before resending."
      return
    end

    sent_count = Rails.cache.read(user_rate_key).to_i
    if sent_count >= MAX_INVITES_PER_HOUR
      redirect_to networks_path, status: :see_other, alert: "You have reached the hourly invitation limit. Please try again later."
      return
    end

    expires_at = INVITE_TOKEN_TTL.from_now
    invite_token = Rails.application.message_verifier(:network_company_invite).generate(
      {
        inviter_id: current_user.id,
        company_name: company_name.presence,
        email: email,
        expires_at: expires_at.iso8601
      },
      expires_in: INVITE_TOKEN_TTL,
      purpose: :network_company_invite
    )

    begin
      NetworkInvitationMailer.invite_company(
        inviter: current_user,
        company_name: company_name.presence,
        recipient_email: email,
        invite_token: invite_token,
        message: message.presence,
        signup_url: new_user_registration_url(invite_token: invite_token),
        expires_in: INVITE_TOKEN_TTL,
        expires_at: expires_at
      ).deliver_later

      Rails.cache.write(user_rate_key, sent_count + 1, expires_in: 1.hour)
      Rails.cache.write(recipient_rate_key, true, expires_in: 15.minutes)

      notice_target = company_name.present? ? "#{company_name} (#{email})" : email
      redirect_to networks_path, status: :see_other, notice: "Invitation sent to #{notice_target}."
    rescue StandardError => e
      Rails.logger.error "[NetworksController#invite] Failed to queue invitation email: #{e.class} - #{e.message}"
      redirect_to networks_path, status: :see_other, alert: "Unable to send the invitation right now. Please try again later."
    end
  end
end
