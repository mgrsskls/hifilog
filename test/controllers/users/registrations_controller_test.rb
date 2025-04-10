require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test 'new' do
    get new_user_registration_url
    assert_response :success

    sign_in users(:one)

    get new_user_registration_url
    assert_response :redirect
    assert_redirected_to dashboard_root_url
  end

  test 'edit' do
    get edit_user_registration_url
    assert_response :redirect
    assert_redirected_to new_user_session_url

    sign_in users(:one)

    get edit_user_registration_url
    assert_response :success
  end

  test 'create' do
    params = {
      user: {
        user_name: 'user_name',
        email: 'mail@example.com',
        password: 'passwordpassword',
        password_confirmation: 'passwordpassword',
      }
    }
    post user_registration_url, params: params
    assert_response :redirect
    assert_redirected_to root_url # user will be redirected to root as they first have to activate their account

    sign_in users(:one)

    post user_registration_url, params: params
    assert_response :redirect
    assert_redirected_to dashboard_root_url
  end

  test 'update' do
    user_name = 'new name'
    params = {
      user: {
        user_name:,
        current_password: 'encrypted_password'
      },
    }
    patch user_registration_url, params: params
    assert_response :redirect
    assert_redirected_to new_user_session_url

    sign_in users(:one)

    patch user_registration_url, params: params
    assert_response :redirect
    assert_redirected_to edit_user_registration_url

    patch user_registration_url, params: params.merge(
      {
        delete_avatar: true,
        delete_decorative_image: true,
      }
    )
    assert_response :redirect
    assert_redirected_to edit_user_registration_url
  end

  test 'user can sign up and confirm account' do
    # Simulate visiting the sign-up page
    get new_user_registration_path
    assert_response :success

    # Generate a unique email to avoid conflicts
    email = "testuser_#{SecureRandom.hex(4)}@example.com"

    # Fill in and submit the sign-up form
    assert_difference('User.count', 1) do
      post user_registration_path, params: {
        user: {
          user_name: 'user_name',
          email: email,
          password: 'passwordpassword',
          password_confirmation: 'passwordpassword'
        }
      }
    end

    # Check if user was created but not yet confirmed
    user = User.last
    assert_equal email, user.email
    assert_not user.confirmed?

    confirmation_email = ActionMailer::Base.deliveries.last
    assert_match 'Confirmation instructions', confirmation_email.subject

    confirmation_url = "http://localhost:3000/user/confirmation?confirmation_token=#{user.confirmation_token}"
    assert confirmation_email.body.encoded.include?("<a href=\"#{confirmation_url}\">Confirm my account</a>"), true

    # Visit the confirmation link to confirm the user
    get confirmation_url
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_match 'Your email address has been successfully confirmed', response.body

    # Reload user and verify confirmation
    user.reload
    assert user.confirmed?
  end
end
