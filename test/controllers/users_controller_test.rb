require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get users_path
    assert_response :success
  end

  test 'show' do
    # profile hidden
    get user_path(id: users(:hidden).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_path(id: users(:logged_in_only).user_name)
    assert_response :redirect
    assert_redirected_to new_user_session_path(redirect: user_path(id: users(:logged_in_only).user_name))

    # profile visible for logged in and logged out users
    get user_path(id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    # profile hidden
    get user_path(id: users(:hidden).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_path(id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_path(id: users(:visible).user_name)
    assert_response :success
  end

  test 'prev_owneds' do
    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :redirect
    assert_redirected_to new_user_session_path(
      redirect: user_previous_products_path(user_id: users(:logged_in_only).user_name)
    )

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success
  end
end
