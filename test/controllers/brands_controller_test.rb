# frozen_string_literal: true

require 'test_helper'

class BrandsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get brands_url
    assert_response :success
  end

  test 'index canonical url includes page when not on first page' do
    with_kaminari_per_page(1) do
      get brands_url(page: 2)
      assert_response :success
      assert_select 'link[rel="canonical"][href=?]', brands_url(page: 2)
    end
  end

  test 'index category path' do
    get brands_category_url(categories(:one).slug)
    assert_response :success
  end

  test 'index subcategory path' do
    get brands_subcategory_url(categories(:one).slug, sub_categories(:one).slug)
    assert_response :success
  end

  test 'index rejects mismatched category and sub_category with 404' do
    get brands_subcategory_url(categories(:two).slug, sub_categories(:one).slug)
    assert_response :not_found
  end

  test 'legacy brands category query redirects with 301' do
    get brands_url(category: categories(:one).slug)
    assert_redirected_to brands_category_url(categories(:one).slug)
    assert_response :moved_permanently
  end

  test 'index with sort on category path' do
    get brands_category_url(categories(:one).slug, sort: 'name_asc')
    assert_response :success
  end

  test 'show' do
    get brand_url(id: brands(:one).friendly_id)
    assert_response :success
  end

  test 'brand products all' do
    brand = brands(:one)
    get brand_products_url(brand.friendly_id)
    assert_response :success
  end

  test 'brand products category path' do
    brand = brands(:one)
    get brand_brand_products_category_url(brand.friendly_id, categories(:one).slug)
    assert_response :success
  end

  test 'brand products subcategory path' do
    brand = brands(:one)
    get brand_brand_products_subcategory_url(brand.friendly_id, categories(:one).slug,
                                             sub_categories(:one).slug)
    assert_response :success
  end

  test 'brand products rejects mismatched slugs with 404' do
    brand = brands(:one)
    get brand_brand_products_subcategory_url(brand.friendly_id, categories(:two).slug,
                                             sub_categories(:one).slug)
    assert_response :not_found
  end

  test 'legacy brand products category query redirects with 301' do
    brand = brands(:one)
    composite = "#{sub_categories(:one).category.slug}[#{sub_categories(:one).slug}]"
    get brand_products_url(brand.friendly_id, category: composite)
    assert_redirected_to brand_brand_products_subcategory_url(brand.friendly_id,
                                                              sub_categories(:one).category.slug,
                                                              sub_categories(:one).slug)
    assert_response :moved_permanently
  end

  test 'products canonical url includes page when not on first page' do
    with_kaminari_per_page(5) do
      brand = brands(:one)
      get brand_products_url(brand.slug, page: 2)
      assert_response :success
      assert_select 'link[rel="canonical"][href=?]', brand_products_url(brand.slug, page: 2)
    end
  end

  test 'products category canonical includes page when not on first page' do
    with_kaminari_per_page(5) do
      brand = brands(:one)
      get brand_brand_products_category_url(brand.friendly_id, categories(:one).slug, page: 2)
      assert_response :success
      assert_select 'link[rel="canonical"][href=?]',
                    brand_brand_products_category_url(brand.friendly_id, categories(:one).slug,
                                                      page: 2)
    end
  end

  test 'new' do
    get new_brand_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_brand_url
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'

    get new_brand_url(sub_category: sub_categories(:one).slug)
    assert_response :success
  end

  test 'create' do
    params = {
      brand: {
        name: 'name'
      }
    }

    post brands_url, params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    post brands_url, params: params
    assert_response :redirect
    assert_redirected_to brand_url(id: Brand.last.friendly_id)
  end

  test 'edit' do
    path = edit_brand_url(id: brands(:one).slug)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'update' do
    brand = brands(:one)
    name = 'new name'
    params = {
      brand: {
        name:,
        discontinued: !brand.discontinued
      }
    }

    patch brand_url(brand), params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch brand_url(brand), params: params
    assert_response :redirect
    assert_redirected_to brand_url(id: name.parameterize)
  end

  test 'changelog' do
    get brand_changelog_url(brand_id: brands(:one).friendly_id)
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
    assert_response :success
  end

  test 'changelog returns 404 for an unknown brand' do
    get brand_changelog_url(brand_id: 'no-such-brand')

    assert_response :not_found
  end

  test 'filter by category returns only brands in that category' do
    get brands_category_url(categories(:one).slug)
    assert_response :success
    expected_names = Brand.joins(:sub_categories)
                          .where(sub_categories: { category_id: categories(:one).id })
                          .distinct
                          .pluck(:name)
    expected_names.each do |name|
      assert_match name, @response.body
    end
  end

  test 'filter by category[sub_category] returns only brands in that sub_category' do
    get brands_subcategory_url(sub_categories(:one).category.slug, sub_categories(:one).slug)
    assert_response :success
    expected_names = Brand.joins(:sub_categories)
                          .where(sub_categories: { id: sub_categories(:one).id })
                          .distinct
                          .pluck(:name)
    expected_names.each do |name|
      assert_match name, @response.body
    end
  end

  test 'filter by status returns only discontinued brands' do
    get brands_url, params: { brands: { status: 'discontinued' } }
    assert_response :success
    Brand.where(discontinued: true).pluck(:name).each do |name|
      assert_match name, @response.body
    end
  end

  test 'filter by query returns only matching brands' do
    brand = brands(:one)
    get brands_url, params: { brands: { query: brand.name } }
    assert_response :success
    assert_match brand.name, @response.body
  end

  test 'brands index has no noindex follow robots meta without filters' do
    get brands_url
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'brands index emits noindex follow when query filter applied' do
    brand = brands(:one)
    get brands_url, params: { brands: { query: brand.name } }
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'brand products category path only has no noindex follow robots meta' do
    brand = brands(:one)
    get brand_brand_products_category_url(brand.friendly_id, categories(:one).slug)
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'brand products emits noindex follow when product filter applied' do
    brand = brands(:one)
    get brand_brand_products_category_url(brand.friendly_id, categories(:one).slug),
        params: { products: { diy_kit: '1' } }
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'bare brands url renders the hub, not the brand list' do
    get brands_url

    assert_response :success
    assert_select '.CatalogueHub'
    assert_select '.EntityList--brands', count: 0
  end

  test 'hub links every category and sub category' do
    get brands_url

    Category.find_each do |category|
      assert_select 'a[href=?]', brands_category_path(category.friendly_id)
    end
    SubCategory.find_each do |sub_category|
      assert_select 'a[href=?]',
                    brands_subcategory_path(sub_category.category.friendly_id,
                                            sub_category.friendly_id)
    end
  end

  # The hub lists categories, not brands, so an ItemList would describe items that are not
  # on the page.
  test 'hub emits CollectionPage and breadcrumbs but no ItemList' do
    get brands_url

    types = css_select('script[type="application/ld+json"]').map { |node| JSON.parse(node.text)['@type'] }

    assert_includes types, 'CollectionPage'
    assert_includes types, 'BreadcrumbList'
    assert_not_includes types, 'ItemList'
  end

  test 'hub canonical is the bare brands url' do
    get brands_url

    assert_select 'link[rel="canonical"][href=?]', brands_url
  end

  test 'hub search posts brand queries back to the brands index' do
    get brands_url

    assert_select 'form[action=?] input[name=?]', brands_path, 'brands[query]'
  end

  {
    'sort' => { sort: 'name_asc' },
    'page' => { page: 2 },
    'brand query' => { brands: { query: 'zmf' } },
    'brand status' => { brands: { status: 'discontinued' } },
    'product diy_kit' => { products: { diy_kit: '1' } }
  }.each do |label, params|
    test "brands url with a #{label} param renders the list, not the hub" do
      get brands_url(**params)

      assert_response :success
      assert_select '.CatalogueHub', count: 0
    end
  end

  # Campaign params are appended to shared links constantly; they must not downgrade the hub.
  test 'tracking params still render the brands hub' do
    get brands_url(utm_source: 'newsletter', utm_medium: 'email')

    assert_response :success
    assert_select '.CatalogueHub'
  end

  test 'category and sub category paths keep their brand listings' do
    get brands_category_url(categories(:one).slug)

    assert_response :success
    assert_select '.CatalogueHub', count: 0
    assert_select '.EntityList--brands'

    get brands_subcategory_url(categories(:one).slug, sub_categories(:one).slug)

    assert_response :success
    assert_select '.CatalogueHub', count: 0
    assert_select '.EntityList--brands'
  end
end
