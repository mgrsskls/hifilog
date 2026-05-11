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
    path = brand_changelog_url(brand_id: brands(:one).friendly_id)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'

    brands(:one).update(name: 'new name')

    get path
    assert_response :success
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
end
