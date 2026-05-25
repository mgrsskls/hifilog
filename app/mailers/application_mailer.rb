# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: '"hifilog.com" <info@mail.hifilog.com>'
  layout 'mailer'
end
