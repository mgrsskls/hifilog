require 'test_helper'

class BrandsControllerTest < ActionDispatch::IntegrationTest
  index_params = [
    { category: ['amplifiers', 'amplifiers[headphone-amplifiers]'] },
    { sort: ['name_asc'] },
    { status: ['discontinued'] },
    { country: ['DE'] },
    { 'products[diy_kit]': ['1'], },
    { 'products[custom_attributes]': [{ amplifier_channel_type: ['1'] }] },
    { query: ['atrium'] }
  ]

  show_products_params = [
    { category: ['amplifiers', 'amplifiers[headphone-amplifiers]'] },
    { sort: ['name_asc'] },
    { status: ['discontinued'] },
    { 'products[diy_kit]': ['1'], },
    { 'products[custom_attributes]': [{ amplifier_channel_type: ['1'] }] },
    { query: ['atrium'] }
  ]

  test 'index' do
    get brands_url
    assert_response :success
  end

  (1..index_params.size).each do |n|
    index_params.combination(n).each do |params_group|
      values = params_group.map { |param| param.values.first }
      value_combinations = values.first.product(*values[1..])

      value_combinations.each do |combo|
        params = params_group.map(&:keys).flatten.zip(combo).to_h

        define_method("test_index_#{params}") do
          get brands_url, params: params
          assert_response :success
        end
      end
    end
  end

  test 'show' do
    get brand_url(id: brands(:one).friendly_id)
    assert_response :success
  end

  (1..show_products_params.size).each do |n|
    show_products_params.combination(n).each do |params_group|
      values = params_group.map { |param| param.values.first }
      value_combinations = values.first.product(*values[1..])

      value_combinations.each do |combo|
        params = params_group.map(&:keys).flatten.zip(combo).to_h

        define_method("test_show_products_#{params}") do
          get brand_products_url(brand_id: brands(:one).slug), params: params
          assert_response :success
        end
      end
    end
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

  test 'filter by category returns only brands in that category' do
    get brands_url(category: categories(:one).slug)
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
    get brands_url(category: "#{sub_categories(:one).category.slug}[#{sub_categories(:one).slug}]")
    assert_response :success
    expected_names = Brand.joins(:sub_categories)
                          .where(sub_categories: { id: sub_categories(:one).id })
                          .distinct
                          .pluck(:name)
    expected_names.each do |name|
      assert_match name, @response.body
    end
  end

  test 'filter by sub_category redirects to category[sub_category]' do
    get brands_url(sub_category: sub_categories(:one).slug)
    assert_response :redirect
    assert_redirected_to brands_url(category: "#{sub_categories(:one).category.slug}[#{sub_categories(:one).slug}]")
  end

  test 'filter by status returns only discontinued brands' do
    get brands_url(status: 'discontinued')
    assert_response :success
    Brand.where(discontinued: true).pluck(:name).each do |name|
      assert_match name, @response.body
    end
  end

  test 'filter by query returns only matching brands' do
    brand = brands(:one)
    get brands_url(query: brand.name)
    assert_response :success
    assert_match brand.name, @response.body
  end
end
