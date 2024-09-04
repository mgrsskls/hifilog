require 'test_helper'

class ProductVariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product_variant = product_variants(:one)
  end

  test 'should get new' do
    get product_variants_new_url(product_id: products(:one).id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get product_variants_new_url(product_id: products(:one).id)
    assert_response :success
  end

  test 'should create product_variant' do
    post product_product_variants_url(product_id: products(:one).id), params: {
      product_variant: {
        name: 'name',
        discontinued: false
      }
    }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    assert_difference('ProductVariant.count') do
      post product_product_variants_url(product_id: products(:one).id), params: {
        product_variant: {
          name: 'name',
          discontinued: false
        }
      }
    end

    assert_redirected_to product_variant_url(
      product_id: ProductVariant.last.product.friendly_id,
      variant: 'name'
    )
  end

  test 'should show product_variant' do
    get product_variant_url(
      product_id: @product_variant.product.friendly_id,
      variant: @product_variant.friendly_id
    )
    assert_response :success
  end

  test 'should update product_variant' do
    patch product_product_variant_url(
      id: @product_variant.id,
      product_id: @product_variant.product.friendly_id,
    ), params: { product_variant: {
      name: 'name'
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    patch product_product_variant_url(
      id: @product_variant.id,
      product_id: @product_variant.product.friendly_id,
    ), params: { product_variant: {
      name: 'name'
    } }
    assert_redirected_to product_variant_url(
      product_id: @product_variant.product.friendly_id,
      variant: 'name'
    )
  end
end
