require 'test_helper'

class UserControllerTest < ActionDispatch::IntegrationTest
  test 'dashboard' do
    get dashboard_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_root_path
    assert_response :success
  end

  test 'products' do
    get dashboard_products_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_products_path
    assert_response :success

    get dashboard_products_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'bookmarks' do
    get dashboard_bookmarks_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_bookmarks_path
    assert_response :success

    get dashboard_bookmarks_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'prev_owneds' do
    get dashboard_prev_owneds_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_prev_owneds_path
    assert_response :success

    get dashboard_prev_owneds_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'contributions' do
    get dashboard_contributions_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_contributions_path
    assert_response :success
  end
end
