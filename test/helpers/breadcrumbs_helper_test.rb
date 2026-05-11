# frozen_string_literal: true

require 'test_helper'

class BreadcrumbsHelperTest < ActionView::TestCase
  include ApplicationHelper

  delegate :params, to: :controller

  test 'products catalogue breadcrumb at root uses canonical for products index' do
    replace_request_env!('https://www.example.com/products')
    canonical = 'https://www.example.com/products?page=2'
    json = products_catalogue_breadcrumb_json_ld(category: nil, sub_category: nil, canonical_url: canonical)

    assert_equal 'BreadcrumbList', json['@type']
    elems = json['itemListElement']
    assert_equal 2, elems.size
    assert_equal APP_NAME, elems.first['name']
    assert_equal root_url, elems.first['item']
    assert_equal Product.model_name.human.pluralize, elems.last['name']
    assert_equal canonical, elems.last['item']
  end

  test 'products catalogue breadcrumb includes category and subcategory' do
    replace_request_env!('https://www.example.com/products/c/amplifiers/headphone-amplifiers')
    category = categories(:one)
    sub = sub_categories(:one)
    canonical = 'https://www.example.com/products/c/amplifiers/headphone-amplifiers'
    json = products_catalogue_breadcrumb_json_ld(category:, sub_category: sub, canonical_url: canonical)

    elems = json['itemListElement']
    assert_equal 4, elems.size
    assert_equal category.name, elems[2]['name']
    assert_equal products_category_url(category.friendly_id), elems[2]['item']
    assert_equal sub.name, elems[3]['name']
    assert_equal canonical, elems[3]['item']
  end

  test 'brands catalogue breadcrumb includes category only' do
    replace_request_env!('https://www.example.com/brands/c/amplifiers')
    category = categories(:one)
    canonical = 'https://www.example.com/brands/c/amplifiers'
    json = brands_catalogue_breadcrumb_json_ld(category:, sub_category: nil, canonical_url: canonical)

    elems = json['itemListElement']
    assert_equal 3, elems.size
    assert_equal category.name, elems.last['name']
    assert_equal canonical, elems.last['item']
  end

  test 'brand show breadcrumb ends on brand url' do
    brand = brands(:one)
    replace_request_env!("https://www.example.com/brands/#{brand.friendly_id}")
    canonical = brand_url(brand)
    json = brand_show_breadcrumb_json_ld(brand:, canonical_url: canonical)

    elems = json['itemListElement']
    assert_equal 3, elems.size
    assert_equal brand.name, elems.last['name']
    assert_equal canonical, elems.last['item']
  end

  test 'brand products breadcrumb includes nested category path' do
    brand = brands(:one)
    category = categories(:one)
    sub = sub_categories(:one)
    replace_request_env!('https://www.example.com')
    canonical = brand_brand_products_subcategory_url(brand, category.friendly_id, sub.friendly_id)
    json = brand_products_breadcrumb_json_ld(brand:, category:, sub_category: sub, canonical_url: canonical)

    elems = json['itemListElement']
    assert_equal 5, elems.size
    assert_equal brand.name, elems[2]['name']
    assert_equal brand_url(brand), elems[2]['item']
    assert_equal category.name, elems[3]['name']
    assert_equal sub.name, elems[4]['name']
    assert_equal canonical, elems[4]['item']
  end

  test 'product show breadcrumb uses primary taxonomy then product' do
    product = products(:one)
    sub = sub_categories(:one)
    category = categories(:one)
    replace_request_env!('https://www.example.com/products/feliks-audio-elise')
    canonical = product_url(id: product.friendly_id)
    json = product_show_breadcrumb_json_ld(product:, canonical_url: canonical)

    elems = json['itemListElement']
    assert_equal 5, elems.size
    assert_equal category.name, elems[2]['name']
    assert_equal products_category_url(category.friendly_id), elems[2]['item']
    assert_equal sub.name, elems[3]['name']
    assert_equal product.display_name, elems[4]['name']
    assert_equal canonical, elems[4]['item']
  end

  test 'product variant show breadcrumb appends variant after parent product' do
    product = products(:with_variants)
    variant = product_variants(:one)
    replace_request_env!('https://www.example.com')
    variant_url = product_variant_url(product_id: product.friendly_id, id: variant.friendly_id)
    json = product_variant_show_breadcrumb_json_ld(product:, product_variant: variant, canonical_url: variant_url)

    elems = json['itemListElement']
    assert_equal 6, elems.size
    assert_equal product.display_name, elems[4]['name']
    assert_equal product_url(id: product.friendly_id), elems[4]['item']
    assert_includes elems[5]['name'], variant.name
    assert_equal variant_url, elems[5]['item']
  end

  test 'events upcoming breadcrumb has two items' do
    replace_request_env!('https://www.example.com/events')
    canonical = 'https://www.example.com/events'
    json = events_index_breadcrumb_json_ld(active_events: :upcoming, canonical_url: canonical, selected_year: nil)

    elems = json['itemListElement']
    assert_equal 2, elems.size
    assert_equal BreadcrumbsHelper::EVENTS_INDEX_BREADCRUMB_NAME, elems.last['name']
    assert_equal canonical, elems.last['item']
  end

  test 'events past breadcrumb adds year segment' do
    replace_request_env!('https://www.example.com/events/past?year=2020')
    canonical = 'https://www.example.com/events/past?year=2020'
    json = events_index_breadcrumb_json_ld(active_events: :past, canonical_url: canonical, selected_year: 2020)

    elems = json['itemListElement']
    assert_equal 3, elems.size
    assert_equal events_url, elems[1]['item']
    assert_equal 'Past (2020)', elems[2]['name']
    assert_equal canonical, elems[2]['item']
  end
end
