class ApplicationMailer < ActionMailer::Base
  default from: "Tax Form Hub <#{ENV.fetch('SMTP_EMAIL', 'taxformhub@meteorsoftware.com')}>"
  layout "mailer"
  helper MailerHelper

  include Rails.application.routes.url_helpers
end
