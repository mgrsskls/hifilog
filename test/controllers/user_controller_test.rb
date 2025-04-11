require 'test_helper'

class UserControllerTest < ActionDispatch::IntegrationTest
  test 'dashboard' do
    get dashboard_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_root_path
    assert_response :success
  end

  test 'products' do
    get dashboard_products_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_products_path
    assert_response :success

    get dashboard_products_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'bookmarks' do
    get dashboard_bookmarks_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_bookmarks_path
    assert_response :success

    get dashboard_bookmarks_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'prev_owneds' do
    get dashboard_prev_owneds_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_prev_owneds_path
    assert_response :success

    get dashboard_prev_owneds_path(category: 'headphone-amplifiers')
    assert_response :success
  end

  test 'contributions' do
    get dashboard_contributions_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_contributions_path
    assert_response :success
  end

  test 'history' do
    get dashboard_history_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_history_path
    assert_response :success
  end

  test 'statistics' do
    get dashboard_statistics_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_statistics_root_path
    assert_response :success
  end

  test 'has' do
    get has_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get has_path

    res = JSON.parse(@response.body)
    assert_nil res[:brands]
    assert_nil res[:products]
    assert_nil res[:product_variants]
    assert_response :success

    get has_path, params: {
      brands: [brands(:one).id, brands(:two).id],
      products: [products(:one).id, products(:two).id],
      product_variants: [product_variants(:one).id, product_variants(:two).id]
    }

    res = JSON.parse(@response.body)
    assert_equal [
      { 'id' => brands(:one).id, 'in_collection' => true, 'previously_owned' => false },
      { 'id' => brands(:two).id, 'in_collection' => false, 'previously_owned' => true }
    ], res['brands']
    assert_equal [
      { 'id' => products(:one).id, 'in_collection' => true, 'previously_owned' => false },
      { 'id' => products(:two).id, 'in_collection' => false, 'previously_owned' => true }
    ], res['products']
    assert_equal [
      { 'id' => product_variants(:one).id, 'in_collection' => true, 'previously_owned' => false },
      { 'id' => product_variants(:two).id, 'in_collection' => false, 'previously_owned' => true }
    ], res['product_variants']
    assert_response :success
  end
end
