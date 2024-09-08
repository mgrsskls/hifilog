require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get users_path
    assert_response :success
  end

  test 'show' do
    # profile hidden
    get user_path(id: 'doesnotexist')
    assert_response :not_found

    # profile hidden
    get user_path(id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_path(id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_path(id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    # profile hidden
    get user_path(id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_path(id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_path(id: users(:visible).user_name)
    assert_response :success

    # with setup
    get user_path(id: users(:one).user_name, setup: users(:one).setups.first.id)
    assert_response :success

    # with subcategory
    get user_path(
      id: users(:one).user_name,
      category: users(:one).products.first.sub_categories.first.name.parameterize
    )
    assert_response :success

    # with setup and subcategory
    get user_path(
      id: users(:one).user_name,
      setup: users(:one).setups.first.id,
      category: users(:one).products.first.sub_categories.first.name.parameterize
    )
    assert_response :success
  end

  test 'prev_owneds' do
    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success

    sign_in users(:visible)

    # profile hidden
    get user_previous_products_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_previous_products_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_previous_products_path(user_id: users(:visible).user_name)
    assert_response :success
  end

  test 'history' do
    # profile hidden
    get user_history_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_history_path(user_id: users(:logged_in_only).user_name)
    assert_response :not_found

    # profile visible for logged in and logged out users
    get user_history_path(user_id: users(:one).user_name)
    assert_response :success

    sign_in users(:one)

    # profile hidden
    get user_history_path(user_id: users(:hidden).user_name)
    assert_response :not_found

    # profile visible only for logged in users
    get user_history_path(user_id: users(:logged_in_only).user_name)
    assert_response :success

    # profile visible for logged in and logged out users
    get user_history_path(user_id: users(:one).user_name)
    assert_response :success
  end
end
