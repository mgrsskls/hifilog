# frozen_string_literal: true

require 'zlib'
require 'test_helper'

class ProductItemsControllerTest < ActionDispatch::IntegrationTest
  parameter_combinations = [
    { sort: ['name_asc'] },
    { status: ['discontinued'] },
    { country: ['DE'] },
    { diy_kit: ['1'] },
    { custom_attributes: [{ amplifier_channel_type: ['1'] }] },
    { query: ['atrium'] }
  ]

  CATALOG_INDEX_BASES = [
    { suffix: 'all', url_fragment: ->(_query) { [:products_url] } },
    { suffix: 'category', url_fragment: lambda { |_query|
      [:products_category_url, 'amplifiers']
    } },
    { suffix: 'subcategory', url_fragment: lambda { |_query|
      [:products_subcategory_url, 'amplifiers', 'headphone-amplifiers']
    } }
  ].freeze

  CATALOG_INDEX_BASES.each do |base|
    (1..parameter_combinations.size).each do |n|
      parameter_combinations.combination(n).each do |params_group|
        values = params_group.map { |param| param.values.first }
        value_combinations = values.first.product(*values[1..])

        value_combinations.each do |combo|
          params = params_group.map(&:keys).flatten.zip(combo).to_h
          combo_id = Zlib.crc32(params.inspect)

          define_method("test_index_#{base[:suffix]}_#{combo_id}") do
            route_method, *route_args = base[:url_fragment].call(params)
            get send(route_method, *route_args, **params.transform_keys(&:to_sym))
            assert_response :success
          end
        end
      end
    end
  end

  test 'index' do
    get products_url
    assert_response :success
  end

  test 'category path' do
    get products_category_url(categories(:one).slug)
    assert_response :success
  end

  test 'subcategory path' do
    get products_subcategory_url(categories(:one).slug, sub_categories(:one).slug)
    assert_response :success
  end

  test 'rejects mismatched category and sub_category slugs with 404' do
    get products_subcategory_url(categories(:two).slug, sub_categories(:one).slug)
    assert_response :not_found
  end

  test 'legacy category query redirects to category path with 301' do
    get products_url(category: categories(:one).slug)
    assert_redirected_to products_category_url(categories(:one).slug)
    assert_response :moved_permanently
  end

  test 'legacy category bracket query redirects to subcategory path with 301' do
    sub = sub_categories(:one)
    composite = "#{sub.category.slug}[#{sub.slug}]"
    get products_url(category: composite)
    assert_redirected_to products_subcategory_url(sub.category.slug, sub.slug)
    assert_response :moved_permanently
  end

  test 'index canonical url includes page when not on first page' do
    with_kaminari_per_page(5) do
      get products_url(page: 2)
      assert_response :success
      assert_select 'link[rel="canonical"][href=?]', products_url(page: 2)
    end
  end

  test 'subcategory canonical url includes page when not on first page' do
    with_kaminari_per_page(5) do
      get products_subcategory_url(categories(:one).slug, sub_categories(:one).slug, page: 2)
      assert_response :success
      assert_select 'link[rel="canonical"][href=?]',
                    products_subcategory_url(categories(:one).slug, sub_categories(:one).slug,
                                             page: 2)
    end
  end

  test 'index has no noindex follow robots meta without filters' do
    get products_url
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'category path without filters has no noindex follow robots meta' do
    get products_category_url(categories(:one).slug)
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'index emits noindex follow when sort filter applied' do
    get products_url(sort: 'name_asc')
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end
end
