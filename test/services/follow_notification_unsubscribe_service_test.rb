# frozen_string_literal: true

require 'test_helper'

class FollowNotificationUnsubscribeServiceTest < ActiveSupport::TestCase
  setup do
    @original_secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = 'test-follow-notification-unsubscribe-secret'
    @user = users(:one)
  end

  teardown do
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = @original_secret
  end

  test 'generate_token and decode_token round trip with user id' do
    token = FollowNotificationUnsubscribeService.generate_token(@user.email)

    assert token.present?
    assert_equal @user, FollowNotificationUnsubscribeService.decode_token(token)
  end

  test 'decode_token normalizes url-encoded tokens' do
    token = FollowNotificationUnsubscribeService.generate_token(@user.email)
    encoded = CGI.escape(token)

    assert_equal @user, FollowNotificationUnsubscribeService.decode_token(encoded)
  end

  test 'generate_token returns nil when secret is absent' do
    ENV.delete('NEWSLETTER_UNSUBSCRIBE_SECRET')

    assert_nil FollowNotificationUnsubscribeService.generate_token(@user.email)
  end

  test 'decode_token returns nil for invalid tokens' do
    assert_nil FollowNotificationUnsubscribeService.decode_token('invalid')
    assert_nil FollowNotificationUnsubscribeService.decode_token(nil)
    assert_nil FollowNotificationUnsubscribeService.decode_token('')
  end

  test 'generate_token returns nil for unknown email' do
    assert_nil FollowNotificationUnsubscribeService.generate_token('unknown@example.com')
  end

  test 'tokens are not valid for newsletter unsubscribe' do
    token = FollowNotificationUnsubscribeService.generate_token(@user.email)

    assert_nil NewsletterUnsubscribeService.decode_token(token)
  end
end
