# frozen_string_literal: true

require 'test_helper'

class Users::UnlocksControllerTest < ActionDispatch::IntegrationTest
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

  test 'create rejects unlock resend when turnstile verification fails' do
    Cloudflare::Turnstile::Rails.configuration.secret_key = '2x0000000000000000000000000000000AA'

    post user_unlock_url, params: { user: { email: users(:one).email } }

    assert_redirected_to new_user_unlock_path
    assert_equal I18n.t('user_form.turnstile_failed'), flash[:alert]
  end

  test 'create sends unlock instructions when turnstile passes' do
    user = users(:one)
    user.lock_access!
    ActionMailer::Base.deliveries.clear

    assert_difference('ActionMailer::Base.deliveries.size', 1) do
      post user_unlock_url, params: { user: { email: user.email } }
    end

    assert_redirected_to new_user_session_path
    assert_equal I18n.t('devise.unlocks.send_instructions'), flash[:notice]
    assert_match 'Unlock my account', ActionMailer::Base.deliveries.last.body.encoded

    user.update!(failed_attempts: 0, locked_at: nil, unlock_token: nil)
  end
end
