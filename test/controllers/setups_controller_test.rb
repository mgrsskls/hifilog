require 'test_helper'

class SetupsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get dashboard_setups_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_setups_path
    assert_response :success
  end

  test 'show' do
    setup = setups(:with_products)

    get dashboard_setup_path(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:without_anything)
    get dashboard_setup_path(setup)
    assert_response :not_found

    sign_out users(:without_anything)

    sign_in users(:with_everything)

    get dashboard_setup_path(setup)
    assert_response :success

    get dashboard_setup_path(
      id: setup.id,
      category: setup.possessions.where.not(product_id: nil).first.product.sub_categories.first.slug
    )
    assert_response :success

    get dashboard_setup_path(setups(:without_products))
    assert_response :success
  end

  test 'new' do
    get new_dashboard_setup_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_dashboard_setup_url
    assert_response :success
  end

  test 'edit' do
    user = users(:one)
    setup = user.setups.first

    get edit_dashboard_setup_url(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    get edit_dashboard_setup_url(setup)
    assert_response :success
  end

  test 'create' do
    user = users(:one)
    params = {
      setup: {
        name: 'name',
        private: false
      }
    }

    post setups_url, params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post setups_url, params: params
    assert_response :redirect
    assert_redirected_to dashboard_setups_path
  end

  test 'update' do
    user = users(:one)
    setup = user.setups.first
    params = {
      setup: {
        private: true
      }
    }

    patch setup_url(id: setup.id), params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    patch setup_url(id: setup.id), params: params
    assert_response :redirect
    assert_redirected_to dashboard_setups_path
  end

  test 'destroy' do
    user = users(:one)
    setup = user.setups.first
    setups_count = user.setups.count

    delete setup_path(setup)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete setup_path(setup)

    assert_equal setups_count - 1, user.setups.count
    assert_response :redirect
    assert_redirected_to dashboard_setups_url
  end
end
