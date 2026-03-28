require 'test_helper'

class UserControllerTest < ActionDispatch::IntegrationTest
  include NewsletterHelper

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
      { 'id' => brands(:one).id, 'in_collection' => true, 'previously_owned' => false, 'bookmarked' => false },
      { 'id' => brands(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['brands']
    assert_equal [
      { 'id' => products(:one).id, 'in_collection' => true, 'previously_owned' => false, 'bookmarked' => true },
      { 'id' => products(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['products']
    assert_equal [
      { 'id' => product_variants(:one).id, 'in_collection' => true, 'previously_owned' => false,
        'bookmarked' => true },
      { 'id' => product_variants(:two).id, 'in_collection' => false, 'previously_owned' => true, 'bookmarked' => false }
    ], res['product_variants']
    assert_response :success
  end

  test 'events' do
    get dashboard_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_events_path
    assert_response :success

    get dashboard_events_path(country: 'DE')
    assert_response :success
  end

  test 'past_events' do
    get dashboard_past_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_past_events_path
    assert_response :success

    get dashboard_past_events_path(year: Date.today.year)
    assert_response :success
  end

  test 'counts' do
    get counts_path

    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get counts_path
    res = JSON.parse(@response.body)
    Rails.logger.debug { "Counts response: #{res.inspect}" }
    assert_equal 3, res['products']
    assert_equal 3, res['custom_products']
    assert_equal 3, res['previous_products']
    assert_equal 2, res['setups']
    assert_equal 2, res['bookmarks']
    assert_equal 1, res['events']
    assert_equal 1, res['notes']
    assert_response :success
  end

  test 'newsletter_unsubscribe' do
    user = users(:one)
    user.update(receives_newsletter: true)
    hash = generate_unsubscribe_hash(user.email)

    get newsletters_unsubscribe_path(email: user.email, hash: hash)
    assert_response :redirect
    assert_redirected_to root_path
    assert_equal false, user.reload.receives_newsletter

    user.update(receives_newsletter: true)
    invalid_hash = 'invalid_hash'

    get newsletters_unsubscribe_path(email: user.email, hash: invalid_hash)
    assert_response :redirect
    assert_redirected_to root_path
    assert_equal true, user.reload.receives_newsletter
  end
end
