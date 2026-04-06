class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  include Rails.application.routes.url_helpers
end
