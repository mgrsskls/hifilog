# frozen_string_literal: true

require 'test_helper'

class NewsletterUnsubscribeServiceTest < ActiveSupport::TestCase
  setup do
    @original_secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = 'test-newsletter-unsubscribe-secret'
    @user = users(:one)
  end

  teardown do
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = @original_secret
  end

  test 'generate_token and decode_token round trip with user id' do
    token = NewsletterUnsubscribeService.generate_token(@user.email)

    assert token.present?
    assert_equal @user, NewsletterUnsubscribeService.decode_token(token)
  end

  test 'decode_token accepts legacy email tokens' do
    token = ActiveSupport::MessageVerifier.new(ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET')).generate(@user.email)

    assert_equal @user, NewsletterUnsubscribeService.decode_token(token)
  end

  test 'decode_token accepts sha256 email tokens' do
    token = ActiveSupport::MessageVerifier.new(
      ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET'),
      digest: 'SHA256'
    ).generate(@user.email.downcase)

    assert_equal @user, NewsletterUnsubscribeService.decode_token(token)
  end

  test 'decode_token normalizes url-encoded tokens' do
    token = NewsletterUnsubscribeService.generate_token(@user.email)
    encoded = CGI.escape(token)

    assert_equal @user, NewsletterUnsubscribeService.decode_token(encoded)
  end

  test 'generate_token returns nil when secret is absent' do
    ENV.delete('NEWSLETTER_UNSUBSCRIBE_SECRET')

    assert_nil NewsletterUnsubscribeService.generate_token(@user.email)
  end

  test 'decode_token returns nil when secret is absent' do
    token = NewsletterUnsubscribeService.generate_token(@user.email)
    ENV.delete('NEWSLETTER_UNSUBSCRIBE_SECRET')

    assert_nil NewsletterUnsubscribeService.decode_token(token)
  end

  test 'decode_token returns nil for invalid tokens' do
    assert_nil NewsletterUnsubscribeService.decode_token('invalid')
    assert_nil NewsletterUnsubscribeService.decode_token(nil)
    assert_nil NewsletterUnsubscribeService.decode_token('')
  end

  test 'generate_token returns nil for unknown email' do
    assert_nil NewsletterUnsubscribeService.generate_token('unknown@example.com')
  end
end
