require 'test_helper'

class DeviseAuthTest < ActionDispatch::IntegrationTest
  test 'logged out user cant access admin area' do
    get admin_dashboard_path
    assert_response :redirect
    assert_redirected_to new_admin_user_session_path
  end

  test 'user cant access admin area' do
    sign_in users(:visible)
    get admin_dashboard_path
    assert_response :redirect
    assert_redirected_to new_admin_user_session_path
  end

  test 'admin user can access admin area' do
    sign_in admin_users(:admin_user)
    get admin_dashboard_path
    assert_response :success
  end

  test 'user cant access dashboard' do
    get dashboard_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test 'logged in user can access dashboard' do
    sign_in users(:visible)
    get dashboard_root_path
    assert_response :success
  end
end
