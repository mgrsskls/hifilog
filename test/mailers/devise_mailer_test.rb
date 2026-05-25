# frozen_string_literal: true

require 'test_helper'

class DeviseMailerTest < ActionMailer::TestCase
  test 'confirmation instructions use the shared mailer layout' do
    user = users(:one)
    mail = Devise::Mailer.confirmation_instructions(user, 'faketoken', {})

    body = mail.body.decoded

    assert_match 'HiFi Log', body
    assert_match 'Confirm my account', body
  end
end
