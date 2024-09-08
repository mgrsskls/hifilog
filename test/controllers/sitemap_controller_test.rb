require 'test_helper'

class SitemapControllerTest < ActionDispatch::IntegrationTest
  test 'sitemap' do
    get sitemap_path
    assert_response :success
  end
end
