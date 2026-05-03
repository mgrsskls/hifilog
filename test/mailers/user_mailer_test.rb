# frozen_string_literal: true

require 'test_helper'

class NewsletterSigning
  include NewsletterHelper
end

class UserMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test 'newsletter_email' do
    original_secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = 'NEWSLETTER_UNSUBSCRIBE_SECRET'

    user = users(:one)
    mail = UserMailer.newsletter_email(user.email, user.user_name, 'Hi %user_name%')

    assert_equal 'hifilog.com Newsletter', mail.subject
    assert_equal [user.email], mail.to
    assert_equal ['newsletter@mail.hifilog.com'], mail.from
    assert_match 'Hi one_username', mail.body.encoded

    unsubscribe_url = newsletters_unsubscribe_url(email: user.email,
                                                  hash: NewsletterSigning.new.generate_unsubscribe_hash(user.email))
    header_value = mail.header['List-Unsubscribe'].decoded
    assert_includes header_value, unsubscribe_url
    assert header_value.strip.start_with?('<')
    assert header_value.strip.end_with?('>')
  ensure
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = original_secret
  end
end
