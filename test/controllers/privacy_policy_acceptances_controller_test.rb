# frozen_string_literal: true

require 'test_helper'

class PrivacyPolicyAcceptancesControllerTest < ActionDispatch::IntegrationTest
  test 'new requires sign in' do
    get new_privacy_policy_acceptance_path
    assert_redirected_to new_user_session_path
  end

  test 'create requires sign in' do
    post privacy_policy_acceptance_path, params: { privacy_policy_accepted: '1' }
    assert_redirected_to new_user_session_path
  end

  test 'create records acceptance for user with outdated policy' do
    user = users(:privacy_policy_outdated)
    sign_in user

    assert_changes -> { user.reload.privacy_policy_version }, from: 'v1', to: PrivacyPolicy::VERSION do
      post privacy_policy_acceptance_path, params: { privacy_policy_accepted: '1' }
    end

    assert_redirected_to dashboard_root_path
    assert_equal I18n.t('privacy_policy_overlay.accepted'), flash[:notice]
    assert user.privacy_policy_accepted_at.present?
  end

  test 'create rejects when checkbox is not accepted' do
    sign_in users(:privacy_policy_outdated)

    post privacy_policy_acceptance_path

    assert_redirected_to new_privacy_policy_acceptance_path
    assert_equal I18n.t('privacy_policy_overlay.required'), flash[:alert]
    assert_equal 'v1', users(:privacy_policy_outdated).reload.privacy_policy_version
  end

  test 'destroy deletes account' do
    user = users(:privacy_policy_outdated)
    sign_in user

    assert_difference('User.count', -1) do
      delete privacy_policy_acceptance_path
    end

    assert_redirected_to root_path
    assert_equal I18n.t('privacy_policy_overlay.account_deleted'), flash[:notice]
    assert_nil User.find_by(id: user.id)
  end
end
