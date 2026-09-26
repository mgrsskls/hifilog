# frozen_string_literal: true

require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @turnstile_site_key = Cloudflare::Turnstile::Rails.configuration.site_key
    @turnstile_secret_key = Cloudflare::Turnstile::Rails.configuration.secret_key
    Cloudflare::Turnstile::Rails.configuration.site_key = '1x00000000000000000000AA'
    Cloudflare::Turnstile::Rails.configuration.secret_key = '1x0000000000000000000000000000000AA'
  end

  teardown do
    Cloudflare::Turnstile::Rails.configuration.site_key = @turnstile_site_key
    Cloudflare::Turnstile::Rails.configuration.secret_key = @turnstile_secret_key
  end

  test 'new shows the turnstile widget' do
    get new_user_session_url

    assert_select 'form [data-sitekey=?]', '1x00000000000000000000AA'
  end

  test 'create rejects sign in when turnstile verification fails and keeps the redirect' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'

    post user_session_url(redirect: brands_path), params: {
      user: { email: 'user@example.com', password: 'encrypted_password' }
    }

    assert_redirected_to new_user_session_path(redirect: brands_path)
    assert_equal I18n.t('user_form.turnstile_failed'), flash[:alert]
    assert_nil session['warden.user.user.key']
  end

  test 'a failed turnstile check does not count as a failed sign in attempt' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'

    post user_session_url, params: { user: { email: 'user@example.com', password: 'wrong-password' } }

    assert_equal 0, users(:one).reload.failed_attempts
  end

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
