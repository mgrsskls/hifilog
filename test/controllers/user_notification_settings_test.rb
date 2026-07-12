# frozen_string_literal: true

require 'test_helper'

class UserNotificationSettingsTest < ActionDispatch::IntegrationTest
  test 'notification settings requires sign in' do
    get dashboard_notification_settings_path
    assert_redirected_to new_user_session_path
  end

  test 'notification settings shows follow notification and newsletter sections' do
    sign_in users(:one)

    get dashboard_notification_settings_path
    assert_response :success
    assert_select 'h1', text: I18n.t('headings.notifications')
    assert_select 'h3', text: I18n.t('user.notification_settings.follow_notifications.heading')
    assert_select 'h3', text: I18n.t('user.notification_settings.newsletter.heading')
    assert_select 'a.Sidebar-link[href=?][aria-current="true"]', dashboard_notification_settings_path
    assert_select 'input[name="user[receives_follow_notifications]"]', count: 2
    assert_select 'input[name="user[receives_newsletter]"]', count: 2
    assert_select 'input[name="user[current_password]"]', count: 0
  end

  test 'update notification settings changes follow notification preference' do
    user = users(:one)
    sign_in user

    patch dashboard_notification_settings_path, params: {
      user: { receives_follow_notifications: false, receives_newsletter: user.receives_newsletter }
    }

    assert_redirected_to dashboard_notification_settings_path
    assert_equal I18n.t('user.notification_settings.updated'), flash[:notice]
    assert_not user.reload.receives_follow_notifications?
  end

  test 'update notification settings changes newsletter preference' do
    user = users(:one)
    user.update!(receives_newsletter: true)
    sign_in user

    patch dashboard_notification_settings_path, params: {
      user: { receives_follow_notifications: user.receives_follow_notifications, receives_newsletter: false }
    }

    assert_redirected_to dashboard_notification_settings_path
    assert_equal I18n.t('user.notification_settings.updated'), flash[:notice]
    assert_not user.reload.receives_newsletter?
  end

  test 'update notification settings ignores other user attributes' do
    user = users(:one)
    original_visibility = user.profile_visibility
    sign_in user

    patch dashboard_notification_settings_path, params: {
      user: { receives_follow_notifications: false, receives_newsletter: false, profile_visibility: 'hidden' }
    }

    assert_redirected_to dashboard_notification_settings_path
    assert_equal original_visibility, user.reload.profile_visibility
  end
end
