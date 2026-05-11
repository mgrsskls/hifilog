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

  test 'new with redirect param emits noindex follow robots meta' do
    get new_user_session_url(redirect: '/brands')
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'new without redirect does not emit noindex follow robots meta' do
    get new_user_session_url
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow', count: 0
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
