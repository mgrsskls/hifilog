# frozen_string_literal: true

require 'test_helper'

class FollowNotificationUnsubscribesControllerTest < ActionDispatch::IntegrationTest
  test 'GET renders a confirmation page without mutating' do
    with_newsletter_unsubscribe_secret do
      user = users(:one)
      user.update(receives_follow_notifications: true)
      hash = FollowNotificationUnsubscribeService.generate_token(user.email)

      get follow_notifications_unsubscribe_path(hash: hash)
      assert_response :success
      assert_select 'form[action=?]', follow_notifications_unsubscribe_path(hash: hash)
      assert_equal true, user.reload.receives_follow_notifications?

      get follow_notifications_unsubscribe_path(hash: 'invalid_hash')
      assert_response :success
      assert_match I18n.t('user_follow.notifications.invalid_unsubscribe_link'), response.body
      assert_equal true, user.reload.receives_follow_notifications?
    end
  end

  test 'GET sets a no-referrer policy to avoid leaking the hash' do
    with_newsletter_unsubscribe_secret do
      hash = FollowNotificationUnsubscribeService.generate_token(users(:one).email)

      get follow_notifications_unsubscribe_path(hash: hash)
      assert_equal 'no-referrer', response.headers['Referrer-Policy']
    end
  end

  test 'one-click unsubscribe via POST' do
    with_newsletter_unsubscribe_secret do
      user = users(:one)
      user.update(receives_follow_notifications: true)
      hash = FollowNotificationUnsubscribeService.generate_token(user.email)

      post follow_notifications_unsubscribe_path(hash: hash), params: { 'List-Unsubscribe' => 'One-Click' }
      assert_response :success
      assert_equal '', response.body
      assert_equal false, user.reload.receives_follow_notifications?
    end
  end

  test 'one-click POST rejects invalid token' do
    with_newsletter_unsubscribe_secret do
      user = users(:one)
      user.update(receives_follow_notifications: true)

      post follow_notifications_unsubscribe_path(hash: 'invalid_hash'), params: { 'List-Unsubscribe' => 'One-Click' }
      assert_response :bad_request
      assert_equal true, user.reload.receives_follow_notifications?
    end
  end

  test 'confirmation button submits a plain POST' do
    with_newsletter_unsubscribe_secret do
      user = users(:one)
      user.update(receives_follow_notifications: true)
      hash = FollowNotificationUnsubscribeService.generate_token(user.email)

      post follow_notifications_unsubscribe_path(hash: hash)
      assert_response :redirect
      assert_redirected_to root_path
      assert_equal I18n.t('user_follow.notifications.unsubscribed'), flash[:notice]
      assert_equal false, user.reload.receives_follow_notifications?
    end
  end

  private

  def with_newsletter_unsubscribe_secret
    original_secret = ENV.fetch('NEWSLETTER_UNSUBSCRIBE_SECRET', nil)
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = 'NEWSLETTER_UNSUBSCRIBE_SECRET'
    yield
  ensure
    ENV['NEWSLETTER_UNSUBSCRIBE_SECRET'] = original_secret
  end
end
