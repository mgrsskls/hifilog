# frozen_string_literal: true

require 'test_helper'

class UserLockableTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
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
end
