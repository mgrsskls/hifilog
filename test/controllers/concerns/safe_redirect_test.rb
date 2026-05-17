# frozen_string_literal: true

require 'test_helper'

class SafeRedirectTest < ActionDispatch::IntegrationTest
  test 'after sign in rejects external redirect' do
    get new_user_session_path(redirect: 'https://evil.com/phish')
    assert_response :success
    assert_select 'input[name=redirect]', count: 0

    post user_session_path, params: {
      user: { email: users(:one).email, password: 'encrypted_password' },
      redirect: 'https://evil.com/phish'
    }
    assert_redirected_to dashboard_root_path
  end

  test 'after sign in allows relative redirect' do
    path = dashboard_products_path
    post user_session_path, params: {
      user: { email: users(:one).email, password: 'encrypted_password' },
      redirect: path
    }
    assert_redirected_to path
  end

  test 'sign in form only echoes validated redirect paths' do
    get new_user_session_path(redirect: 'https://evil.com/phish')
    assert_response :success
    assert_select "input[name=redirect][value='https://evil.com/phish']", count: 0

    get new_user_session_path(redirect: dashboard_products_path)
    assert_select "input[name=redirect][value='#{dashboard_products_path}']", count: 1
  end

  test 'after sign in rejects javascript redirect' do
    post user_session_path, params: {
      user: { email: users(:one).email, password: 'encrypted_password' },
      redirect: 'javascript:alert(1)'
    }
    assert_redirected_to dashboard_root_path
  end

  test 'after sign in rejects protocol-relative redirect' do
    post user_session_path, params: {
      user: { email: users(:one).email, password: 'encrypted_password' },
      redirect: '//evil.com/phish'
    }
    assert_redirected_to dashboard_root_path
  end

  test 'move_to_prev_owneds rejects external redirect_to' do
    user = users(:one)
    possession = possessions(:current_product)
    sign_in user

    post possession_move_to_prev_owneds_url(possession), params: { redirect_to: 'https://evil.com/phish' }
    assert_response :redirect
    assert_not_equal 'https://evil.com/phish', response.redirect_url
  end
end
