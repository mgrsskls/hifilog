require 'test_helper'

class FeedControllerTest < ActionDispatch::IntegrationTest
  test 'rss' do
    get rss_path
    assert_response :success
  end
end
