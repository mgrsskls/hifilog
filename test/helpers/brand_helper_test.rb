# frozen_string_literal: true

require 'test_helper'

class BrandHelperTest < ActionView::TestCase
  include ApplicationHelper
  include BrandHelper

  delegate :params, to: :controller

  test 'brands_index_item_list_json_ld describes ItemList of brands' do
    brand = brands(:one)
    brands_scope = Brand.where(id: brand.id)
    meta_desc = "  All brands \n on HiFi Log "
    controller.params = ActionController::Parameters.new(sort: 'name_desc')
    replace_request_env!('https://www.example.com/brands?sort=name_desc')

    json = brands_index_item_list_json_ld(
      brands: brands_scope,
      meta_desc:,
      category: nil,
      sub_category: nil,
      canonical_url: 'https://www.example.com/brands'
    )

    assert_equal 'ItemList', json['@type']
    assert_equal Brand.model_name.human.pluralize, json['name']
    assert_equal 'All brands on HiFi Log', json['description']
    assert_equal 'https://schema.org/ItemListOrderDescending', json['itemListOrder']
    assert_equal 'https://www.example.com/brands', json['url']

    row = json['itemListElement'].first
    assert_equal 'ListItem', row['@type']
    assert_equal 1, row['position']
    item = row['item']
    assert_equal 'Brand', item['@type']
    assert_equal brand.name, item['name']
    assert_equal brand_url(brand), item['url']
  end

  test 'brand_show_json_ld describes Brand entity' do
    brand = brands(:one)
    meta_desc = "  Feliks summary \n line "
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/brands/feliks-audio')

    json = brand_show_json_ld(brand:, meta_desc:)

    assert_equal 'https://schema.org', json['@context']
    assert_equal 'Brand', json['@type']
    assert_equal brand.name, json['name']
    assert_equal brand_url(brand), json['url']
    assert_equal 'Feliks summary line', json['description']
  end

  test 'brand_show_json_ld sameAs uses normalized website URL when present' do
    brand = brands(:one)
    def brand.website
      'example.com/audio'
    end
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/brands/feliks-audio')

    assert_equal ['https://example.com/audio'], brand_show_json_ld(brand:, meta_desc: nil)['sameAs']
  end

  test 'brand_show_json_ld skips invalid sameAs URLs' do
    brand = brands(:one)
    def brand.website
      'mailto:hello@example.com'
    end
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/brands/feliks-audio')

    assert_not brand_show_json_ld(brand:, meta_desc: nil).key?('sameAs')
  end

  test 'brands_index_item_list_json_ld name follows scoped category heading' do
    category = categories(:one)
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/brands/c/amplifiers')

    assert_equal categories(:one).name, brands_index_item_list_json_ld(
      brands: Brand.none,
      meta_desc: nil,
      category:,
      sub_category: nil
    )['name']
  end

  test 'brand_products_path_with_filter passes category slug and merges extra filters' do
    brand = brands(:one)
    category = categories(:one)

    path = brand_products_path_with_filter(brand, category, nil, diy_kit: '1')

    assert_match(
      %r{/brands/#{Regexp.escape(brand.friendly_id)}/products/c/#{Regexp.escape(category.friendly_id)}},
      path
    )
    assert_match(/diy_kit=1/, path)
  end

  test 'brand_products_path_with_filter encodes sub category constraint' do
    brand = brands(:one)
    category = categories(:one)
    sub_category = sub_categories(:one)

    path = brand_products_path_with_filter(brand, category, sub_category, {})

    brand_seg = Regexp.escape(brand.friendly_id)
    category_seg = Regexp.escape(category.friendly_id)
    sub_seg = Regexp.escape(sub_category.friendly_id)
    assert_match(%r{/brands/#{brand_seg}/products/c/#{category_seg}/#{sub_seg}}, path)
  end
end
