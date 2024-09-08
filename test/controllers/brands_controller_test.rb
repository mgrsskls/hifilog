require 'test_helper'

class BrandsControllerTest < ActionDispatch::IntegrationTest
  test 'should get index' do
    get brands_url
    assert_response :success

    get brands_url(sort: :name_asc)
    assert_response :success

    get brands_url(sort: :name_desc)
    assert_response :success

    get brands_url(sort: :products_asc)
    assert_response :success

    get brands_url(sort: :products_desc)
    assert_response :success

    get brands_url(sort: :country_asc)
    assert_response :success

    get brands_url(sort: :country_desc)
    assert_response :success

    get brands_url(sort: :added_asc)
    assert_response :success

    get brands_url(sort: :added_desc)
    assert_response :success

    get brands_url(sort: :updated_asc)
    assert_response :success

    get brands_url(sort: :updated_desc)
    assert_response :success

    get brands_url(sub_category: sub_categories(:one).slug)
    assert_response :success

    get brands_url(category: categories(:one).slug)
    assert_response :success

    get brands_url(status: 'discontinued')
    assert_response :success

    get brands_url(status: 'does-not-exist')
    assert_response :success

    get brands_url(letter: 'a')
    assert_response :success

    get brands_url(letter: 'a', sub_category: sub_categories(:one).slug, status: 'discontinued')
    assert_response :success

    get brands_url(letter: 'a', sub_category: sub_categories(:one).slug)
    assert_response :success

    get brands_url(letter: 'a', status: 'discontinued')
    assert_response :success

    get brands_url(sub_category: sub_categories(:one).slug, status: 'discontinued')
    assert_response :success

    get brands_url(letter: 'a', category: categories(:one).slug, status: 'discontinued')
    assert_response :success

    get brands_url(letter: 'a', category: categories(:one).slug)
    assert_response :success

    get brands_url(category: categories(:one).slug, status: 'discontinued')
    assert_response :success

    get brands_url(query: brands(:one).name)
    assert_response :success

    get brands_url(query: brands(:one).name, sub_category: brands(:one).products.first.sub_categories.first.slug)
    assert_response :success

    get brands_url(query: 'does-not-exist')
    assert_response :success
  end

  test 'should get show' do
    brand = brands(:one)

    get brand_url(id: brand.friendly_id)
    assert_response :success

    get brand_url(id: brand.friendly_id, sort: :name_asc)
    assert_response :success

    get brand_url(id: brand.friendly_id, sort: :name_desc)
    assert_response :success

    get brand_url(id: brand.friendly_id, sort: :release_date_asc)
    assert_response :success

    get brand_url(id: brand.friendly_id, sort: :release_date_desc)
    assert_response :success

    get brand_url(id: brand.friendly_id, status: 'discontinued')
    assert_response :success

    get brand_url(id: brand.friendly_id, status: 'does-not-exist')
    assert_response :success

    get brand_url(id: brand.friendly_id, letter: 'a')
    assert_response :success

    get brand_url(id: brand.friendly_id, query: brand.products.first.name)
    assert_response :success

    get brand_url(id: brand.friendly_id, sub_category: brand.products.first.sub_categories.first.slug)
    assert_response :success
  end

  test 'new' do
    get new_brand_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_brand_url
    assert_response :success

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

    brands(:one).update(name: 'new name')

    get path
    assert_response :success
  end
end
