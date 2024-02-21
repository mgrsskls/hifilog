require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get users_path
    assert_response :success
  end

  test 'show' do
    # profile hidden
    get user_path(id: users(:one).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_path(id: users(:two).user_name)
    assert_response :redirect
    assert_redirected_to new_user_session_path(redirect: user_path(id: users(:two).user_name))

    # profile visible for logged in and logged out users
    get user_path(id: users(:three).user_name)
    assert_response :success

    sign_in users(:three)

    # profile hidden
    get user_path(id: users(:one).user_name)
    assert_response :redirect
    assert_redirected_to root_path

    # profile visible only for logged in users
    get user_path(id: users(:two).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_path(id: users(:three).user_name)
    assert_response :success
  end
end
