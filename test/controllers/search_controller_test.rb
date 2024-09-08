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
end
