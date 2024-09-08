require 'test_helper'

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get products_url
    assert_response :success

    get products_url(sort: :name_asc)
    assert_response :success

    get products_url(sort: :name_desc)
    assert_response :success

    get products_url(sort: :release_date_asc)
    assert_response :success

    get products_url(sort: :release_date_desc)
    assert_response :success

    get products_url(sort: :added_asc)
    assert_response :success

    get products_url(sort: :added_desc)
    assert_response :success

    get products_url(sort: :updated_asc)
    assert_response :success

    get products_url(sort: :updated_desc)
    assert_response :success

    get products_url(sub_category: sub_categories(:one).slug)
    assert_response :success

    get products_url(category: categories(:one).slug)
    assert_response :success

    get products_url(status: 'discontinued')
    assert_response :success

    get products_url(status: 'does-not-exist')
    assert_response :success

    get products_url(letter: 'a')
    assert_response :success

    get products_url(letter: 'a', sub_category: sub_categories(:one).slug, status: 'discontinued')
    assert_response :success

    get products_url(letter: 'a', sub_category: sub_categories(:one).slug)
    assert_response :success

    get products_url(letter: 'a', status: 'discontinued')
    assert_response :success

    get products_url(sub_category: sub_categories(:one).slug, status: 'discontinued')
    assert_response :success

    get products_url(letter: 'a', category: categories(:one).slug, status: 'discontinued')
    assert_response :success

    get products_url(letter: 'a', category: categories(:one).slug)
    assert_response :success

    get products_url(category: categories(:one).slug, status: 'discontinued')
    assert_response :success

    get products_url(query: products(:one).name)
    assert_response :success

    get products_url(query: products(:one).name, sub_category: products(:one).sub_categories.first.slug)
    assert_response :success

    get products_url(query: 'does-not-exist')
    assert_response :success
  end

  test 'show' do
    user = users(:one)

    get product_url(id: user.products.first.friendly_id)
    assert_response :success

    sign_in users(:one)

    get product_url(id: possessions(:current_product).product.friendly_id)
    assert_response :success

    get product_url(id: possessions(:prev_product).product.friendly_id)
    assert_response :success
  end

  test 'new' do
    get new_product_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get new_product_url
    assert_response :success

    get new_product_url(sub_category: sub_categories(:one).slug)
    assert_response :success

    get new_product_url(brand_id: brands(:one).id)
    assert_response :success
  end

  test 'create' do
    brand = brands(:one)
    params = {
      product: {
        sub_category_ids: [brand.products.first.sub_categories.first.id],
        discontinued: false,
        product_options_attributes: {
          0 => { option: 'option' }
        }
      }
    }

    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name',
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    # with existing brand
    # with sub category which is already sub category of brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name',
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    sub_category = SubCategory.create!(name: 'sub category', category_id: categories(:one).id)

    # with existing brand
    # with sub category which is not yet sub category of brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 2',
          sub_category_ids: [sub_category.id],
          brand_id: brand.id
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    # with new brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 3',
          brand_attributes: {
            name: 'brand name'
          }
        }
      }
    )
    assert_response :redirect
    assert_redirected_to product_url(id: Product.last.friendly_id)

    # with invalid new brand
    post products_url, params: params.deep_merge(
      {
        product: {
          name: 'product name 4',
          brand_attributes: {}
        }
      }
    )
    assert_response :unprocessable_entity
  end

  test 'edit' do
    path = edit_product_url(id: products(:one).slug)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
  end

  test 'update' do
    product = products(:one)
    name = 'new name'
    params = {
      product: {
        name:,
        discontinued: !product.discontinued,
      },
      product_options_attributes: {
        0 => {
          id: product.product_options.first.id,
          option: 'new option name'
        },
        1 => {
          id: product.product_options.second.id,
          option: ''
        },
        2 => {
          option: 'new option'
        },
        3 => {
          option: ''
        }
      }
    }

    patch product_url(id: product.id), params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch product_url(id: product.id), params: params
    assert_response :redirect
    assert_redirected_to product_url(id: Product.find(product.id).friendly_id)
  end

  test 'changelog' do
    path = product_changelog_url(product_id: products(:one).friendly_id)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success

    products(:one).update(name: 'new name')

    get path
    assert_response :success
  end
end
