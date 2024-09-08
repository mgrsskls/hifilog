require 'test_helper'

class ProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variant = product_variants(:one)
  end

  test 'new' do
    product = products(:one)
    path = product_variants_new_url(product_id: product.id)

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
  end

  test 'create' do
    path = product_product_variants_url(product_id: products(:one).id)
    params = {
      product_variant: {
        name: 'name',
        discontinued: false
      }
    }
    params_with_options = {
      product_variant: {
        name: 'name2',
        discontinued: false
      },
      product_options_attributes: {
        0 => {
          option: ''
        },
        1 => {
          option: 'option2'
        },
      }
    }

    post path, params: params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    assert_difference('ProductVariant.count') do
      post path, params: params
    end

    assert_redirected_to product_variant_url(
      product_id: ProductVariant.last.product.friendly_id,
      id: 'name'
    )

    assert_difference('ProductVariant.count') do
      post path, params: params_with_options
    end
    assert_equal 1, ProductVariant.last.product_options.count
    assert_redirected_to product_variant_url(
      product_id: ProductVariant.last.product.friendly_id,
      id: 'name2'
    )
  end

  test 'create for discontinued brand' do
    product = products(:one)
    path = product_product_variants_url(product_id: product.id)

    product.brand.update!(discontinued: true)

    post path, params: {
      product_variant: {
        name: 'name',
        discontinued: false
      }
    }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    assert_difference('ProductVariant.count') do
      post path, params: {
        product_variant: {
          name: 'name',
          discontinued: false
        },
      }
    end

    assert_equal ProductVariant.last.discontinued, true
    assert_redirected_to product_variant_url(
      product_id: ProductVariant.last.product.friendly_id,
      id: 'name'
    )
  end

  test 'show (logged out user)' do
    get product_variant_url(
      product_id: @product_variant.product.friendly_id,
      id: @product_variant.friendly_id
    )
    assert_response :success
  end

  test 'show (logged in user)' do
    sign_in users(:one)

    get product_variant_url(
      product_id: @product_variant.product.friendly_id,
      id: @product_variant.friendly_id
    )
    assert_response :success
  end

  test 'edit' do
    product_variant = product_variants(:one)

    path = product_edit_variant_url(
      id: product_variant.friendly_id,
      product_id: product_variant.product.friendly_id
    )

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success
  end

  test 'update' do
    product_variant = product_variants(:two)
    update_path = product_product_variant_url(
      id: product_variant.id,
      product_id: product_variant.product.friendly_id,
    )
    name = 'New name'
    update_params = {
      product_variant: {
        name:,
      }
    }
    update_params_with_options = {
      product_variant: {
        name:,
      },
      product_options_attributes: {
        0 => {
          id: product_variant.product_options.first.id,
          option: 'option1 new'
        },
        1 => {
          option: 'option2'
        }
      }
    }
    product_options_count = product_variant.product_options.count

    patch update_path, params: update_params
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch update_path, params: update_params
    assert_equal name, ProductVariant.find(product_variant.id).name
    assert_redirected_to product_variant_url(
      product_id: product_variant.product.friendly_id,
      id: name.parameterize
    )

    patch update_path, params: update_params_with_options
    assert_equal name, ProductVariant.find(product_variant.id).name
    assert_equal product_options_count + 1, ProductVariant.find(product_variant.id).product_options.count
    assert_redirected_to product_variant_url(
      product_id: product_variant.product.friendly_id,
      id: name.parameterize
    )
  end

  test 'changelog' do
    product_variant = product_variants(:one)

    path = product_variant_changelog_url(
      id: product_variant.friendly_id,
      product_id: product_variant.product.friendly_id
    )

    get path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get path
    assert_response :success

    product_variant.update!(name: 'new name')
    get path
    assert_response :success
  end
end
