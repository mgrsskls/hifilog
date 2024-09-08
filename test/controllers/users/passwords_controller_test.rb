require 'test_helper'

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_user_password_url
    assert_response :success

    sign_in users(:one)

    get new_user_password_url
    assert_response :redirect
    assert_redirected_to dashboard_root_url
  end
end
