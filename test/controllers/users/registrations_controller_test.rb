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
end
