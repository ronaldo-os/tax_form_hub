# frozen_string_literal: true

class NetworkInvitationMailer < ApplicationMailer
  INVITE_TOKEN_TTL = 7.days

  def invite_company(inviter:, company_name:, recipient_email:, invite_token:, message: nil, signup_url: nil, expires_in: INVITE_TOKEN_TTL, expires_at: nil)
    @inviter = inviter
    @inviter_company_name = inviter.company&.name.presence || inviter.companies.first&.name.presence || inviter.display_name
    @company_name = company_name
    @recipient_email = recipient_email
    @invite_token = invite_token
    @personal_message = message.presence
    @signup_url = signup_url.presence || new_user_registration_url(invite_token: @invite_token)
    @expires_in = expires_in.presence || INVITE_TOKEN_TTL
    @expires_at = expires_at.presence || (@expires_in.respond_to?(:from_now) ? @expires_in.from_now : Time.current + @expires_in.to_i)

    safe_inviter_subject = @inviter_company_name.to_s.gsub(/[\r\n]+/, " ").strip.truncate(80)

    mail(
      to: @recipient_email,
      subject: "#{safe_inviter_subject} invited you to connect on Tax Form Hub"
    )
  end
end
