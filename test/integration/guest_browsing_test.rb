# frozen_string_literal: true

require 'test_helper'

class GuestBrowsingTest < ActionDispatch::IntegrationTest
  test 'anonymous visitors can browse the root and catalogue pages' do
    get root_path
    assert_response :success

    get brands_path
    assert_response :success

    get brand_path(brands(:one))
    assert_response :success

    get product_path(products(:one))
    assert_response :success

    get search_path, params: { query: 'atrium' }
    assert_response :success
  end

  test 'product items index loads for guests' do
    get product_items_path
    assert_response :success
  end
end
