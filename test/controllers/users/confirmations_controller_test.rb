# frozen_string_literal: true

require 'test_helper'

class Users::ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_user_confirmation_url
    assert_response :success
  end

  test 'show confirms user signs in and redirects to dashboard' do
    password = 'password_one_two345'
    user_name = 'unconfirmed_user_xyz'

    user = User.new(
      email: 'unconfirmed-flow@example.com',
      password: password,
      password_confirmation: password,
      user_name: user_name
    )
    user.skip_confirmation_notification!
    user.save!

    assert_not user.confirmed?

    get user_confirmation_url(confirmation_token: user.confirmation_token)
    assert_redirected_to dashboard_root_path

    assert_predicate user.reload, :confirmed?

    follow_redirect!
    assert_response :success
  end
end
