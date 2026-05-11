# frozen_string_literal: true

require 'test_helper'

class ProductsHelperTest < ActionView::TestCase
  include ApplicationHelper

  delegate :params, to: :controller

  setup do
    @stub_category = nil
    @stub_sub_category = nil
  end

  def current_category
    @stub_category
  end

  def current_sub_category
    @stub_sub_category
  end

  test 'products_index_item_list_json_ld describes ItemList of catalogue Products' do
    product = products(:one)
    brand = brands(:one)
    @products = ProductItem.where(product_slug: product.slug, item_type: 'Product')
    controller.params = ActionController::Parameters.new(sort: 'name_desc')
    replace_request_env!('https://www.example.com/products?sort=name_desc')

    json = products_index_item_list_json_ld(
      products: @products,
      canonical_url: 'https://www.example.com/products'
    )

    assert_equal 'ItemList', json['@type']
    assert_equal Product.model_name.human.pluralize, json['name']
    assert_equal @products.count, json['numberOfItems']
    assert_equal 'https://schema.org/ItemListOrderDescending', json['itemListOrder']
    assert_equal 'https://www.example.com/products', json['url']

    row = json['itemListElement'].first
    assert_equal 'ListItem', row['@type']
    assert_equal 1, row['position']
    item = row['item']
    assert_equal 'Product', item['@type']
    assert_equal product.name, item['name']
    assert_equal product_url(id: product.friendly_id), item['url']
    assert_equal 'Brand', item['brand']['@type']
    assert_equal brand.name, item['brand']['name']
    assert_equal brand_url(brand), item['brand']['url']
  end

  test 'products_index_item_list_json_ld uses variant show URL and variant display name when row is variant' do
    variant_row = ProductItem.where(item_type: 'ProductVariant').first
    assert variant_row

    @products = ProductItem.where(id: variant_row.id)
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/products')

    json = products_index_item_list_json_ld(products: @products)
    row = json['itemListElement'].first
    item = row['item']

    assert_includes item['name'], variant_row.variant_name.to_s
    assert_equal product_variant_url(
      id: variant_row.variant_slug,
      product_id: variant_row.product_slug
    ), item['url']
  end

  test 'products_index_item_list_json_ld list name matches scoped category headings' do
    @stub_category = categories(:one)
    @products = ProductItem.none
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/products?category=test')

    assert_equal categories(:one).name, products_index_item_list_json_ld(products: @products)['name']
  end

  test 'brand_products_item_list_json_ld describes ItemList for brand catalogue' do
    @brand = brands(:one)
    product = products(:one)
    assert_equal @brand.id, product.brand_id

    @products = ProductItem.where(product_slug: product.slug, item_type: 'Product')
    @meta_desc = "  Brand story \n line "
    controller.params = ActionController::Parameters.new
    replace_request_env!("https://www.example.com/brands/#{@brand.friendly_id}/products")

    canonical = "https://www.example.com/brands/#{@brand.friendly_id}/products"
    json = brand_products_item_list_json_ld(
      brand: @brand,
      meta_desc: @meta_desc,
      products: @products,
      canonical_url: canonical
    )

    assert_equal 'ItemList', json['@type']
    assert_equal "#{@brand.name} #{Product.model_name.human.pluralize}", json['name']
    assert_equal 'Brand story line', json['description']
    assert_equal canonical, json['url']
    assert_equal @products.size, json['numberOfItems']
    assert json['itemListElement'].any?
  end

  test 'product_show_json_ld describes Product entity' do
    product = products(:one)
    brand = brands(:one)
    meta_desc = "  Warm tube sound \n line "
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/products/feliks-audio-elise')

    json = product_show_json_ld(product:, meta_desc:, image_urls: nil)

    assert_equal 'https://schema.org', json['@context']
    assert_equal 'Product', json['@type']
    assert_equal product.display_name, json['name']
    assert_equal product_url(id: product.friendly_id), json['url']
    assert_equal 'Warm tube sound line', json['description']
    assert_equal 'Brand', json['brand']['@type']
    assert_equal brand.name, json['brand']['name']
    assert_equal brand_url(brand), json['brand']['url']
    assert_not json.key?('image')
    assert_not json.key?('offers')
  end

  test 'product_show_json_ld emits single image URL when present' do
    product = products(:one)
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/products/feliks-audio-elise')

    json = product_show_json_ld(
      product:,
      meta_desc: nil,
      image_urls: ['https://cdn.example.com/photo.webp']
    )

    assert_equal 'https://cdn.example.com/photo.webp', json['image']
  end

  test 'product_show_json_ld includes releaseDate and category from associations' do
    product = products(:release_date_ymd)
    controller.params = ActionController::Parameters.new
    replace_request_env!("https://www.example.com/products/#{product.friendly_id}")

    json = product_show_json_ld(product:, meta_desc: nil, image_urls: %w[https://a.example/x https://b.example/y])

    assert_equal '2020-06-01', json['releaseDate']
    assert_equal sub_categories(:one).name, json['category']
    assert_equal %w[https://a.example/x https://b.example/y], json['image']
  end

  test 'sub_category_links lists each sub-category with catalogue query params' do
    product = Product.includes(:sub_categories).find(products(:one).id)

    html = sub_category_links(product)

    product.sub_categories.each do |sub|
      assert_includes html, sub.name
      assert_includes html, sub.friendly_id
    end
  end
end
