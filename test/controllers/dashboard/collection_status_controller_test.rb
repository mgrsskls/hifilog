# frozen_string_literal: true

require 'test_helper'

class Dashboard::CollectionStatusControllerTest < ActionDispatch::IntegrationTest
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
      { 'id' => brands(:one).id, 'in_collection' => true, 'previously_owned' => false, 'bookmarked' => true },
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

    get has_path, params: { events: [events(:one).id] }

    res = JSON.parse(@response.body)
    payload = res['events'].sole

    assert_equal events(:one).id, payload['id']
    assert_equal false, payload['in_collection']
    assert_equal true, payload['previously_owned']
    assert_equal false, payload['bookmarked']
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
    assert_equal 4, res['bookmarks']
    assert_equal 1, res['events']
    assert_equal 1, res['notes']
    assert_response :success
  end
end
