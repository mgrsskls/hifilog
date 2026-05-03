# frozen_string_literal: true

require 'test_helper'

class SitemapControllerTest < ActionDispatch::IntegrationTest
  test 'html renders sitemap hierarchy' do
    get sitemap_path
    assert_response :success

    assert_select 'h1', 'Sitemap'
    assert_select 'ul > li' # brands
    assert_select 'a[href^="/brands/"]'
  end

  test 'xml is a urlset with loc entries' do
    get sitemap_path(format: :xml)
    assert_response :success

    assert_includes response.content_type, 'xml'
    assert_match(/<urlset\b/, response.body)
    assert_match(/<loc>/, response.body)
    assert_operator response.body.scan('<url>').size, :>=, 2
  end
end
