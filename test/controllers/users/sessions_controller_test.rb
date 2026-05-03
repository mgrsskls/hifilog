# frozen_string_literal: true

require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_user_session_url
    assert_response :success

    sign_in users(:one)

    get new_user_session_url
    assert_response :redirect
    assert_redirected_to dashboard_root_url
  end

  test 'create' do
    params = {
      user: {
        email: 'user@example.com',
        password: 'encrypted_password'
      }
    }
    post user_session_url, params: params
    assert_response :redirect
    assert_redirected_to dashboard_root_url
  end

  test 'create honors explicit redirect targets' do
    post user_session_url(redirect: brands_path), params: {
      user: {
        email: 'user@example.com',
        password: 'encrypted_password'
      }
    }

    assert_response :redirect
    assert_redirected_to brands_path
  end
end
