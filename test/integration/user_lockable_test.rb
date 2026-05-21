# frozen_string_literal: true

require 'test_helper'

class UserLockableTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear
    reset_lockable_user!(users(:one))
  end

  teardown do
    Rack::Attack.cache.store.clear
    reset_lockable_user!(users(:one))
  end

  test 'warns user on last sign in attempt before lockout' do
    user = users(:one)

    8.times do
      post user_session_url, params: { user: { email: user.email, password: 'wrong-password' } }
    end

    post user_session_url, params: { user: { email: user.email, password: 'wrong-password' } }

    assert_response :unprocessable_entity
    assert_match I18n.t('devise.failure.last_attempt'), response.body

    user.reload
    assert_equal 9, user.failed_attempts
    assert_not user.access_locked?
  end

  test 'locks account after too many failed sign in attempts' do
    user = users(:one)

    10.times do
      post user_session_url, params: { user: { email: user.email, password: 'wrong-password' } }
    end

    user.reload
    assert user.access_locked?
    assert_equal 10, user.failed_attempts

    Rack::Attack.cache.store.clear

    post user_session_url, params: { user: { email: user.email, password: 'encrypted_password' } }

    assert_response :unprocessable_entity
    assert_match(/locked/i, response.body)
  end

  private

  def reset_lockable_user!(user)
    user.update!(failed_attempts: 0, locked_at: nil, unlock_token: nil)
  end
end
