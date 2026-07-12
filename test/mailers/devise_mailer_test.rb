# frozen_string_literal: true

require 'test_helper'

class DeviseMailerTest < ActionMailer::TestCase
  test 'confirmation instructions use the shared mailer layout' do
    user = users(:one)
    mail = Devise::Mailer.confirmation_instructions(user, 'faketoken', {})

    html = mail_body_html(mail)
    text = mail_body_text(mail)

    assert_equal ['info@mail.hifilog.com'], mail.from
    assert mail.multipart?, 'expected multipart email with plain text part'
    assert_match 'HiFi Log', html
    assert_match 'Confirm my account', html
    assert_no_match(/unsubscribe/i, html)
    assert_no_match(/unsubscribe/i, text)
    assert_plain_text_email(text)
    assert_match(%r{https?://}, text)
  end
end
