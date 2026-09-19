# frozen_string_literal: true

require 'test_helper'

class ProductSeriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @series = product_series(:evolution)
    @brand = @series.brand
  end

  def series_path(series = @series)
    brand_series_path(brand_id: series.brand.friendly_id, id: series.friendly_id)
  end

  def create_product(name:, series: @series, **attributes)
    Product.create!(name: "#{name} #{SecureRandom.hex(3)}", brand: @brand, product_series: series,
                    sub_categories: [sub_categories(:one)], **attributes)
  end

  test 'show lists the products of the series' do
    inside = create_product(name: 'Inside')
    outside = create_product(name: 'Outside', series: nil)

    get series_path

    assert_response :success
    assert_select 'h1', text: /Evolution/
    products_list = assert_select('.EntityList--products').to_s
    assert_match inside.name, products_list
    assert_no_match outside.name, products_list
  end

  test 'show is noindex while the series has no products' do
    get series_path

    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'show redirects an old series slug' do
    create_product(name: 'Moved')
    old_slug = @series.slug
    @series.update!(name: 'Evolution Two')

    get brand_series_path(brand_id: @brand.friendly_id, id: old_slug)

    assert_redirected_to series_path(@series.reload)
    assert_response :moved_permanently
  end

  test 'show returns 404 for a series of another brand' do
    get brand_series_path(brand_id: brands(:two).friendly_id, id: @series.slug)

    assert_response :not_found
  end

  test 'index answers the series of the brand as JSON' do
    get brand_series_index_path(brand_id: @brand.id, format: :json)

    assert_response :success
    names = response.parsed_body['series'].pluck('name')
    assert_includes names, 'Evolution'
    assert_not_includes names, 'Heritage'
  end

  test 'new requires sign in' do
    get new_brand_series_path(brand_id: @brand.friendly_id)

    assert_redirected_to new_user_session_path
  end

  test 'create' do
    sign_in users(:one)

    assert_difference 'ProductSeries.count', 1 do
      post brand_series_index_path(brand_id: @brand.friendly_id),
           params: { product_series: { name: 'Reference', description: 'The top line.' } }
    end

    series = @brand.product_series.find_by!(name: 'Reference')
    assert_redirected_to series.path
  end

  test 'create with a duplicate name renders the form again' do
    sign_in users(:one)

    assert_no_difference 'ProductSeries.count' do
      post brand_series_index_path(brand_id: @brand.friendly_id), params: { product_series: { name: 'evolution' } }
    end

    assert_response :unprocessable_content
  end

  test 'update' do
    sign_in users(:one)

    patch series_path, params: { product_series: { description: 'New text' } }

    assert_redirected_to @series.reload.path
    assert_equal 'New text', @series.description
  end

  test 'changelog' do
    get brand_series_changelog_path(brand_id: @brand.friendly_id, series_id: @series.friendly_id)

    assert_response :success
  end

  def edit_path(**)
    edit_brand_series_path(brand_id: @brand.friendly_id, id: @series.friendly_id, **)
  end

  def update_params(product_ids:, selected_ids:, **attributes)
    { product_series: { name: @series.name, **attributes }, product_ids:, selected_ids: }
  end

  test 'edit lists the products of the brand' do
    sign_in users(:one)
    product = create_product(name: 'Listed', series: nil)

    get edit_path(query: product.name)

    assert_response :success
    assert_select "#products input[type=checkbox][value='#{product.id}']"
    assert_select "#series-products-query[form='series-products-search']"
  end

  test 'update saves the series and adds, moves and removes products on the page only' do
    sign_in users(:one)
    add = create_product(name: 'Add', series: nil)
    move = create_product(name: 'Move', series: product_series(:legacy))
    remove = create_product(name: 'Remove')
    untouched = create_product(name: 'Untouched')

    patch series_path, params: update_params(product_ids: [add.id, move.id, remove.id],
                                             selected_ids: [add.id, move.id],
                                             description: 'With products')

    assert_redirected_to @series.reload.path
    assert_equal 'With products', @series.description
    assert_equal @series, add.reload.product_series
    assert_equal @series, move.reload.product_series
    assert_nil remove.reload.product_series
    assert_equal @series, untouched.reload.product_series
  end

  test 'update ignores products of other brands' do
    sign_in users(:one)
    other = products(:two)

    patch series_path, params: update_params(product_ids: [other.id], selected_ids: [other.id])

    assert_nil other.reload.product_series
  end

  test 'update leaves a product that can not join the series and saves the rest' do
    sign_in users(:one)
    invalid = create_product(name: 'Evolution Clash', series: nil)
    valid = create_product(name: 'Joins', series: nil)

    patch series_path, params: update_params(product_ids: [invalid.id, valid.id],
                                             selected_ids: [invalid.id, valid.id],
                                             description: 'Saved anyway')

    assert_redirected_to @series.reload.path
    assert_equal 'Saved anyway', @series.description
    assert_nil invalid.reload.product_series
    assert_equal @series, valid.reload.product_series
    assert_match invalid.name, flash[:alert]
  end

  test 'update leaves a product whose name another product of the brand already has' do
    sign_in users(:one)
    in_series = create_product(name: 'Omega Lupi')
    twin = Product.create!(name: in_series.name, brand: @brand, product_series: product_series(:legacy),
                           sub_categories: [sub_categories(:one)])

    patch series_path, params: update_params(product_ids: [twin.id], selected_ids: [twin.id])

    assert_equal product_series(:legacy), twin.reload.product_series
    assert_match in_series.name, flash[:alert]
    assert_match product_path(id: in_series.reload.friendly_id), flash[:alert]
  end

  # The two products have the same name, so the end state is valid but every order of the two
  # saves has a moment in which both are in the same group.
  test 'update moves two products with the same name between two series in one submit' do
    sign_in users(:one)
    legacy = product_series(:legacy)
    from_series = create_product(name: 'Swap')
    from_legacy = Product.create!(name: from_series.name, brand: @brand, product_series: legacy,
                                  sub_categories: [sub_categories(:one)])

    patch series_path, params: update_params(product_ids: [from_series.id, from_legacy.id],
                                             selected_ids: [from_legacy.id])

    assert_redirected_to @series.reload.path
    assert_nil from_series.reload.product_series
    assert_equal @series, from_legacy.reload.product_series
    assert_nil flash[:alert]
  end

  test 'create can continue to the product list of the edit page' do
    sign_in users(:one)

    post brand_series_index_path(brand_id: @brand.friendly_id),
         params: { product_series: { name: 'Signature' }, assign_products: '1' }

    series = @brand.product_series.find_by!(name: 'Signature')
    assert_redirected_to edit_brand_series_path(brand_id: @brand.friendly_id, id: series.friendly_id,
                                                anchor: 'products')
  end

  test 'brand page lists its series' do
    create_product(name: 'On Brand Page', release_year: 2019)

    get brand_path(id: @brand.friendly_id)

    assert_response :success
    assert_select 'h2', text: 'Evolution series'
  end

  test 'brand page shows the newest products of each series with products' do
    products = Array.new(5) { |index| create_product(name: "Newest #{index}", release_year: 2000 + index) }

    get brand_path(id: @brand.friendly_id)

    assert_response :success
    assert_select 'h2', text: 'Evolution series'
    assert_select 'h2', text: 'Legacy series', count: 0
    section = css_select('.Entity-section--productSeries').first.to_html
    # 5 products: the newest 3, then "+2" instead of the fourth.
    products.last(4).each { |product| assert_includes section, product.name }
    products.first(1).each { |product| assert_not_includes section, product.name }
  end

  test 'brand products page filters by series' do
    inside = create_product(name: 'Filtered In')
    outside = create_product(name: 'Filtered Out', series: nil)

    get brand_products_path(brand_id: @brand.friendly_id, series: @series.slug)

    assert_response :success
    products_list = assert_select('.EntityList--products').to_s
    assert_match inside.name, products_list
    assert_no_match outside.name, products_list
  end

  test 'product page shows the series and its other products' do
    product = create_product(name: 'Shown', release_year: 2000)
    sibling = create_product(name: 'Sibling', release_year: 2001)

    get product_path(id: product.friendly_id)

    assert_response :success
    assert_select 'title', text: /\(Evolution series\)/
    assert_select '.Heading-subline a[href=?]', series_path
    assert_select '.Entity-section--seriesProducts', text: /#{sibling.name}/
  end

  test 'search finds a series' do
    get search_path(query: 'Evolution')

    assert_response :success
    assert_select 'a[href=?]', series_path
  end
end
