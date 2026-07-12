# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @original_secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = 'NEWSLETTER_UNSUBSCRIBE_SECRET'
  end

  teardown do
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = @original_secret
  end

  test 'newsletter_email' do
    user = users(:one)
    mail = UserMailer.newsletter_email(user.email, user.user_name, 'Hi %user_name%')
    text_body = mail_body_text(mail)
    html_body = mail_body_html(mail)

    assert_equal 'hifilog.com Newsletter', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['newsletter@mail.hifilog.com'], mail.from
    assert mail.multipart?

    token = NewsletterUnsubscribeService.generate_token(user.email)
    unsubscribe_url = newsletters_unsubscribe_url(hash: token)
    header_value = mail.header['List-Unsubscribe'].decoded

    assert_includes header_value, unsubscribe_url
    assert header_value.strip.start_with?('<')
    assert header_value.strip.end_with?('>')
    assert_equal 'List-Unsubscribe=One-Click', mail.header['List-Unsubscribe-Post'].decoded
    assert_match 'Hi one_username', text_body
    assert_plain_text_email(text_body)
    assert_includes text_body, unsubscribe_url
    assert_match 'HiFi Log', html_body
  end
end
