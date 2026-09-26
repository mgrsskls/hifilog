# frozen_string_literal: true

require 'test_helper'

class AdminUserLockableTest < ActionDispatch::IntegrationTest
  PASSWORD = 'correct-admin-password'

  setup do
    Rack::Attack.cache.store.clear
    @admin_user = admin_users(:admin_user)
    @admin_user.update!(password: PASSWORD, password_confirmation: PASSWORD)
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  test 'locks the admin account after too many failed sign in attempts' do
    10.times do |i|
      # One IP for each attempt: 'admin logins/ip' allows five, and the lock must hold across IPs.
      sign_in_admin('wrong-password', ip: "203.0.113.#{i}")
    end

    assert @admin_user.reload.access_locked?

    sign_in_admin(PASSWORD, ip: '203.0.113.99')

    assert_response :unprocessable_entity
    assert_match(/locked/i, response.body)
  end

  test 'unlocks the admin account one hour after the lock' do
    @admin_user.lock_access!

    travel 1.hour + 1.minute do
      sign_in_admin(PASSWORD, ip: '203.0.113.99')

      assert_redirected_to admin_root_path
      assert_equal 0, @admin_user.reload.failed_attempts
    end
  end

  test 'sends no unlock email and has no unlock page' do
    assert_no_emails do
      assert_no_enqueued_emails { @admin_user.lock_access! }
    end

    assert_not_respond_to self, :admin_user_unlock_path
  end

  private

  def sign_in_admin(password, ip:)
    post admin_user_session_path,
         params: { admin_user: { email: @admin_user.email, password: } },
         headers: { 'REMOTE_ADDR' => ip }
  end
end
