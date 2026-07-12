# frozen_string_literal: true

require 'test_helper'

class UserProfileSettingsTest < ActionDispatch::IntegrationTest
  test 'profile settings requires sign in' do
    get dashboard_profile_settings_path
    assert_redirected_to new_user_session_path
  end

  test 'profile settings shows visibility and images sections' do
    sign_in users(:one)

    get dashboard_profile_settings_path
    assert_response :success
    assert_select 'h1', text: I18n.t('headings.profile')
    assert_select 'h3', text: I18n.t('user.profile_settings.visibility.heading')
    assert_select 'h3', text: I18n.t('user.profile_settings.images.heading')
    assert_select 'a.Sidebar-link[href=?][aria-current="true"]', dashboard_profile_settings_path
    assert_select 'input[name="user[profile_visibility]"]', count: 3
    assert_select 'input[name="user[receives_follow_notifications]"]', count: 0
    assert_select 'input[name="user[current_password]"][required]'
  end

  test 'update profile settings changes visibility' do
    user = users(:one)
    sign_in user

    patch dashboard_profile_settings_path, params: {
      user: { profile_visibility: 'hidden', current_password: 'encrypted_password' }
    }

    assert_redirected_to dashboard_profile_settings_path
    assert_equal I18n.t('user.profile_settings.updated'), flash[:notice]
    assert user.reload.hidden?
  end

  test 'update profile settings rejects invalid current password' do
    user = users(:one)
    sign_in user

    patch dashboard_profile_settings_path, params: {
      user: { profile_visibility: 'hidden', current_password: 'wrong-password' }
    }

    assert_response :unprocessable_entity
    assert_not user.reload.hidden?
    assert_select 'input[name="user[current_password]"]'
  end

  test 'update profile settings with delete_avatar records avatar_deleted' do
    user = users(:one)
    sign_in user
    user.update!(avatar: one_by_one_png_upload(filename: 'remove-via-profile-settings.png'))
    UserActivity.where(user: user, subject: user, verb: 'avatar_deleted').delete_all

    assert_difference(-> { UserActivity.where(verb: 'avatar_deleted', subject: user).count }, 1) do
      patch dashboard_profile_settings_path, params: {
        user: { profile_visibility: user.profile_visibility, current_password: 'encrypted_password' },
        delete_avatar: true
      }
    end

    assert_redirected_to dashboard_profile_settings_path
    assert_not user.reload.avatar.attached?
    assert UserActivity.exists?(user: user, subject: user, verb: 'avatar_deleted')
  end

  test 'update profile settings with delete_decorative_image purges header image' do
    user = users(:one)
    sign_in user
    user.update!(decorative_image: one_by_one_png_upload(filename: 'remove-header.png'))
    UserActivity.where(user: user, subject: user, verb: 'decorative_image_deleted').delete_all

    assert_difference(-> { UserActivity.where(verb: 'decorative_image_deleted', subject: user).count }, 1) do
      patch dashboard_profile_settings_path, params: {
        user: { profile_visibility: user.profile_visibility, current_password: 'encrypted_password' },
        delete_decorative_image: true
      }
    end

    assert_redirected_to dashboard_profile_settings_path
    assert_not user.reload.decorative_image.attached?
  end

  test 'update profile settings does not delete avatar when password is invalid' do
    user = users(:one)
    sign_in user
    user.update!(avatar: one_by_one_png_upload(filename: 'keep-avatar.png'))

    patch dashboard_profile_settings_path, params: {
      user: { profile_visibility: user.profile_visibility, current_password: 'wrong-password' },
      delete_avatar: true
    }

    assert_response :unprocessable_entity
    assert user.reload.avatar.attached?
  end
end
