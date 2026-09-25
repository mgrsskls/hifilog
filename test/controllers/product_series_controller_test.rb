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

  test 'changelog lists the products that were added and removed' do
    sign_in users(:one)
    added = create_product(name: 'Added', series: nil)
    removed = create_product(name: 'Removed')

    patch assignable_products_path, params: assign_params(selected_ids: [added.id])
    get brand_series_changelog_path(brand_id: @brand.friendly_id, series_id: @series.friendly_id)

    assert_response :success
    added_entry = assert_select('.Changelog-item', text: /#{I18n.t('changelog.product_added')}/).to_s
    assert_match added.name, added_entry
    removed_entry = assert_select('.Changelog-item', text: /#{I18n.t('changelog.product_removed')}/).to_s
    assert_match removed.name, removed_entry
    assert_match users(:one).user_name, removed_entry
  end

  test 'changelog keeps a product that was converted into a variant' do
    product = create_product(name: 'Converted')
    name = product.name

    ProductConversionService.to_variant(product, create_product(name: 'Target', series: nil))
    get brand_series_changelog_path(brand_id: @brand.friendly_id, series_id: @series.friendly_id)

    assert_response :success
    assert_select '.Changelog-item', text: /#{I18n.t('changelog.product_added')}.*#{name}/m
  end

  test 'changelog shows the name of a deleted product' do
    product = create_product(name: 'Gone')
    name = product.name

    product.destroy!
    get brand_series_changelog_path(brand_id: @brand.friendly_id, series_id: @series.friendly_id)

    assert_response :success
    assert_select '.Changelog-item', text: /#{I18n.t('changelog.product_deleted')}.*#{name}/m
  end

  test 'a user who assigns products is a contributor of the series' do
    sign_in users(:one)
    product = create_product(name: 'Contributed', series: nil)
    patch assignable_products_path, params: assign_params(selected_ids: [product.id])
    sign_out users(:one)

    get series_path

    assert_select 'dd', text: /#{users(:one).user_name}/
  end

  def edit_path(**)
    edit_brand_series_path(brand_id: @brand.friendly_id, id: @series.friendly_id, **)
  end

  # products_loaded says that the dialog had loaded its rows, product_ids lists them (by default
  # all products of the brand, as the dialog does); see ProductSeriesController#assignment_changes.
  def assign_params(selected_ids:, products_loaded: '1', product_ids: @brand.products.ids)
    { products_loaded:, product_ids:, selected_ids: }
  end

  def assignable_products_path
    brand_series_products_path(brand_id: @brand.friendly_id, series_id: @series.friendly_id)
  end

  test 'show has a dialog that loads the products of the brand' do
    sign_in users(:one)
    product = create_product(name: 'Listed', series: nil)

    get series_path

    assert_response :success
    assert_select ".Entity-metaLinks button[data-dialog='assign-products']"
    dialog = assert_select("dialog#assign-products[data-picker-src='#{assignable_products_path}']")
    assert_select dialog, "form[action='#{assignable_products_path}'] input[name=_method][value=patch]"
    assert_no_match product.name, dialog.to_s
  end

  test 'show sends signed-out visitors to sign-in instead of the dialog' do
    get series_path

    assert_response :success
    assert_select 'dialog#assign-products', false
    assert_select ".Entity-metaLinks a[href='#{new_user_session_path(redirect: "#{@series.path}#assign-products")}']"
  end

  test 'edit has no products' do
    sign_in users(:one)

    get edit_path

    assert_response :success
    assert_select 'dialog#assign-products', false
  end

  test 'the dialog list has all products of the brand, the products of the series first' do
    sign_in users(:one)
    outside = create_product(name: 'Aaa Outside', series: nil)
    inside = create_product(name: 'Zzz Inside')

    get assignable_products_path

    assert_response :success
    assert_select "input[type=checkbox][value='#{inside.id}'][checked]"
    assert_select "input[type=checkbox][value='#{outside.id}']"
    assert_select "input[type=checkbox][value='#{outside.id}'][checked]", false
    assert_operator response.body.index(inside.name), :<, response.body.index(outside.name)
  end

  test 'the dialog list requires sign in' do
    get assignable_products_path

    assert_redirected_to new_user_session_path
  end

  test 'update saves the name and the description and changes no product' do
    sign_in users(:one)
    product = create_product(name: 'Still In')

    patch series_path, params: { product_series: { name: @series.name, description: 'Only the series' },
                                 **assign_params(selected_ids: []) }

    assert_redirected_to @series.reload.path
    assert_equal 'Only the series', @series.description
    assert_equal @series, product.reload.product_series
  end

  test 'update with an invalid name renders the edit page' do
    sign_in users(:one)

    patch series_path, params: { product_series: { name: '' } }

    assert_response :unprocessable_content
  end

  test 'assign adds, moves and removes products' do
    sign_in users(:one)
    add = create_product(name: 'Add', series: nil)
    move = create_product(name: 'Move', series: product_series(:legacy))
    remove = create_product(name: 'Remove')
    keep = create_product(name: 'Keep')

    patch assignable_products_path, params: assign_params(selected_ids: [add.id, move.id, keep.id])

    assert_redirected_to @series.reload.path
    assert_equal @series, add.reload.product_series
    assert_equal @series, move.reload.product_series
    assert_nil remove.reload.product_series
    assert_equal @series, keep.reload.product_series
  end

  test 'assign requires sign in' do
    product = create_product(name: 'Stays')

    patch assignable_products_path, params: assign_params(selected_ids: [])

    assert_redirected_to new_user_session_path
    assert_equal @series, product.reload.product_series
  end

  # The dialog had not loaded its rows, so the submit says nothing about the products.
  test 'assign without products_loaded changes no product' do
    sign_in users(:one)
    product = create_product(name: 'Still In')

    patch assignable_products_path, params: assign_params(selected_ids: [], products_loaded: nil)

    assert_redirected_to @series.reload.path
    assert_equal @series, product.reload.product_series
  end

  # The product joined the series after the dialog had loaded, so it is not in product_ids.
  test 'assign keeps a product in the series that the dialog did not list' do
    sign_in users(:one)
    listed = create_product(name: 'Listed')
    joined_later = create_product(name: 'Joined Later')

    patch assignable_products_path, params: assign_params(selected_ids: [], product_ids: [listed.id])

    assert_nil listed.reload.product_series
    assert_equal @series, joined_later.reload.product_series
  end

  test 'assign ignores products of other brands' do
    sign_in users(:one)
    other = products(:two)

    patch assignable_products_path, params: assign_params(selected_ids: [other.id])

    assert_nil other.reload.product_series
  end

  test 'assign leaves a product that can not join the series and saves the rest' do
    sign_in users(:one)
    invalid = create_product(name: 'Evolution Clash', series: nil)
    valid = create_product(name: 'Joins', series: nil)

    patch assignable_products_path, params: assign_params(selected_ids: [invalid.id, valid.id])

    assert_redirected_to @series.reload.path
    assert_nil invalid.reload.product_series
    assert_equal @series, valid.reload.product_series
    assert_match invalid.name, flash[:alert]
  end

  test 'assign leaves a product whose name another product of the brand already has' do
    sign_in users(:one)
    in_series = create_product(name: 'Omega Lupi')
    twin = Product.create!(name: in_series.name, brand: @brand, product_series: product_series(:legacy),
                           sub_categories: [sub_categories(:one)])

    patch assignable_products_path, params: assign_params(selected_ids: [in_series.id, twin.id])

    assert_equal product_series(:legacy), twin.reload.product_series
    assert_match in_series.name, flash[:alert]
    assert_match product_path(id: in_series.reload.friendly_id), flash[:alert]
  end

  # The two products have the same name, so the end state is valid but every order of the two
  # saves has a moment in which both are in the same group.
  test 'assign moves two products with the same name between two series in one submit' do
    sign_in users(:one)
    legacy = product_series(:legacy)
    from_series = create_product(name: 'Swap')
    from_legacy = Product.create!(name: from_series.name, brand: @brand, product_series: legacy,
                                  sub_categories: [sub_categories(:one)])

    patch assignable_products_path, params: assign_params(selected_ids: [from_legacy.id])

    assert_redirected_to @series.reload.path
    assert_nil from_series.reload.product_series
    assert_equal @series, from_legacy.reload.product_series
    assert_nil flash[:alert]
  end

  test 'create can continue to the product dialog of the series page' do
    sign_in users(:one)

    post brand_series_index_path(brand_id: @brand.friendly_id),
         params: { product_series: { name: 'Signature' }, assign_products: '1' }

    series = @brand.product_series.find_by!(name: 'Signature')
    assert_redirected_to "#{series.path}#assign-products"
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
