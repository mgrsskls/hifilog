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

  test 'bare products url renders the hub, not the product list' do
    get products_url

    assert_response :success
    assert_select '.CatalogueHub'
    assert_select '.EntityList--products', count: 0
  end

  test 'hub links every category and sub category' do
    get products_url

    Category.find_each do |category|
      assert_select 'a[href=?]', products_category_path(category.friendly_id)
    end
    SubCategory.find_each do |sub_category|
      assert_select 'a[href=?]',
                    products_subcategory_path(sub_category.category.friendly_id,
                                              sub_category.friendly_id)
    end
  end

  test 'hub offers an escape hatch to the full alphabetical list' do
    get products_url

    assert_select 'a[href=?]', products_path(sort: 'name_asc')
  end

  # The hub lists categories, not products, so an ItemList would describe items that are not
  # on the page.
  test 'hub emits CollectionPage and breadcrumbs but no ItemList' do
    get products_url

    types = css_select('script[type="application/ld+json"]').map { |node| JSON.parse(node.text)['@type'] }

    assert_includes types, 'CollectionPage'
    assert_includes types, 'BreadcrumbList'
    assert_not_includes types, 'ItemList'
  end

  test 'hub canonical is the bare products url' do
    get products_url

    assert_select 'link[rel="canonical"][href=?]', products_url
  end

  test 'hub is indexable' do
    get products_url

    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  # Each of these means the visitor asked a question of the catalogue, so they get the list.
  {
    'sort' => { sort: 'name_asc' },
    'page' => { page: 2 },
    'product query' => { products: { query: 'atrium' } },
    'product status' => { products: { status: 'discontinued' } },
    'brand country' => { brands: { country: 'DE' } }
  }.each do |label, params|
    test "products url with a #{label} param renders the list, not the hub" do
      get products_url(**params)

      assert_response :success
      assert_select '.CatalogueHub', count: 0
    end
  end

  # Campaign params are appended to shared links constantly; they must not downgrade the hub.
  test 'tracking params still render the hub' do
    get products_url(utm_source: 'newsletter', utm_medium: 'email')

    assert_response :success
    assert_select '.CatalogueHub'
  end

  # An applied filter must be visible. The fieldset previously keyed its open state and its
  # "filter applied" marker off the country param alone, so a brand status filter was active but
  # invisible: collapsed fieldset, no indicator.
  test 'brand status filter opens and flags the brands fieldset' do
    get products_url(brands: { status: 'discontinued' })

    assert_response :success
    assert_select 'details.Filter-fieldset[open] > summary', text: /Brands/
    assert_select 'details.Filter-fieldset[open] > summary svg[aria-label="Filter applied"]'
  end

  test 'brand country filter opens and flags the brands fieldset' do
    get products_url(brands: { country: 'DE' })

    assert_response :success
    assert_select 'details.Filter-fieldset[open] > summary', text: /Brands/
  end

  test 'brands fieldset stays closed without a brand filter' do
    get products_url(sort: 'name_asc')

    assert_response :success
    assert_select 'details.Filter-fieldset[open] > summary', text: /Brands/, count: 0
  end

  # The non-goal of this change: category pages carry the catalogue's unique content and its
  # links into the product detail pages, so they must keep listing products.
  test 'category and sub category paths keep their product listings' do
    get products_category_url(categories(:one).slug)

    assert_response :success
    assert_select '.CatalogueHub', count: 0
    assert_select '.EntityList--products'

    get products_subcategory_url(categories(:one).slug, sub_categories(:one).slug)

    assert_response :success
    assert_select '.CatalogueHub', count: 0
    assert_select '.EntityList--products'
  end
end
