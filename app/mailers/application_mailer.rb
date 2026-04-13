class ApplicationMailer < ActionMailer::Base
  default from: "[EMAIL_ADDRESS]"
  layout "mailer"

  include Rails.application.routes.url_helpers
end
