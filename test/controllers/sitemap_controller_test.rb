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

    amplifiers = categories(:one)
    sub_one = sub_categories(:one)

    assert_includes response.body, products_category_url(amplifiers.slug).to_s

    assert_includes response.body, brands_category_url(amplifiers.slug).to_s

    assert_includes response.body,
                    products_subcategory_url(amplifiers.slug, sub_one.slug).to_s

    assert_includes response.body,
                    brands_subcategory_url(amplifiers.slug, sub_one.slug).to_s

    event = events(:two)
    assert_includes response.body,
                    event_url(year: event.calendar_year, slug: event.friendly_id).to_s
  end

  test 'xml sitemap omits duplicate loc URLs' do
    get sitemap_path(format: :xml)
    assert_response :success

    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    assert_equal locs.size, locs.uniq.size,
                 "duplicate <loc> entries:\n#{locs.sort.tally.inspect}"
  end
end
