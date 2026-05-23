# frozen_string_literal: true

require 'test_helper'

class PrivacyPolicyAcceptanceTest < ActionDispatch::IntegrationTest
  test 'logged in user with current policy can use the app' do
    sign_in users(:one)

    get dashboard_root_path

    assert_response :success
  end

  test 'logged in user with outdated policy is redirected to acceptance page' do
    sign_in users(:privacy_policy_outdated)

    get dashboard_root_path

    assert_redirected_to new_privacy_policy_acceptance_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t('privacy_policy_overlay.heading')
  end

  test 'logged in user with null policy version is redirected to acceptance page' do
    sign_in users(:privacy_policy_missing)

    get dashboard_root_path

    assert_redirected_to new_privacy_policy_acceptance_path
  end

  test 'validation message is shown on the acceptance page' do
    sign_in users(:privacy_policy_outdated)

    post privacy_policy_acceptance_path
    assert_redirected_to new_privacy_policy_acceptance_path
    follow_redirect!

    assert_response :success
    assert_includes response.body, I18n.t('privacy_policy_overlay.required')
  end

  test 'account recovery routes are not blocked by privacy policy enforcement' do
    sign_in users(:privacy_policy_outdated)

    [new_user_password_path, new_user_confirmation_path, new_user_unlock_path].each do |path|
      get path

      if response.redirect?
        assert_not_equal new_privacy_policy_acceptance_path, response.redirect_url,
                         "expected #{path} not to redirect to privacy policy acceptance"
      else
        assert_response :success, "expected #{path} to succeed"
      end
    end
  end

  test 'logged in user with outdated policy can sign out' do
    sign_in users(:privacy_policy_outdated)

    delete destroy_user_session_path

    assert_response :redirect

    get dashboard_root_path

    assert_redirected_to new_user_session_path
  end

  test 'privacy policy page is reachable while acceptance is required' do
    sign_in users(:privacy_policy_outdated)

    get privacy_policy_path

    assert_response :success
    assert_includes response.body, 'Privacy Policy'
  end

  test 'acceptance page redirects users who already accepted' do
    sign_in users(:one)

    get new_privacy_policy_acceptance_path

    assert_redirected_to dashboard_root_path
  end

  test 'successful acceptance redirects to stored location' do
    sign_in users(:privacy_policy_outdated)

    get dashboard_bookmarks_path
    assert_redirected_to new_privacy_policy_acceptance_path

    post privacy_policy_acceptance_path, params: { privacy_policy_accepted: '1' }

    assert_redirected_to dashboard_bookmarks_path
  end
end
