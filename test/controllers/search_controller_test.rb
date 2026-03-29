# frozen_string_literal: true

require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  test 'search' do
    get search_path(query: 'Feliks')
    assert_response :success

    get search_path(query: ' Feliks ')
    assert_response :success

    get search_path(query: 'F')
    assert_response :success

    get search_path
    assert_response :success
  end

  test 'search xhr with valid query' do
    get search_path(query: 'Feliks'), headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
    assert_response :success
    res = JSON.parse(@response.body)
    assert_equal 'Feliks', res['query']
    assert_not_nil res['html']
  end

  test 'search xhr with query below minimum chars' do
    get search_path(query: 'F'), headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
    assert_response :success
    res = JSON.parse(@response.body)
    assert_equal 'F', res['query']
    assert_nil res['html']
  end

  test 'search xhr without query' do
    get search_path, headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
    assert_response :success
    res = JSON.parse(@response.body)
    assert_nil res['query']
    assert_nil res['html']
  end

  test 'search xhr with filter' do
    get search_path(query: 'Feliks', filter: 'products'), headers: { 'HTTP_X_REQUESTED_WITH' => 'XMLHttpRequest' }
    assert_response :success
    res = JSON.parse(@response.body)
    assert_equal 'Feliks', res['query']
    assert_not_nil res['html']
  end
end
