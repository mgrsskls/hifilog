# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: 'newsletter@mail.hifilog.com'
  layout 'mailer'
end
