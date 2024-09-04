require 'test_helper'

class CustomProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @custom_product = custom_products(:one)
  end

  test 'should get index' do
    get dashboard_custom_products_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get dashboard_custom_products_url
    assert_response :success
  end

  test 'should get new' do
    get dashboard_new_custom_product_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get dashboard_new_custom_product_url
    assert_response :success
  end

  test 'should create custom_product' do
    post custom_products_url, params: { custom_product: {
      name: 'Custom Product',
      sub_category_ids: [
        sub_categories(:one).id,
        sub_categories(:two).id
      ]
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    assert_difference('CustomProduct.count') do
      post custom_products_url, params: { custom_product: {
        name: 'Custom Product',
        sub_category_ids: [
          sub_categories(:one).id,
          sub_categories(:two).id
        ]
      } }
    end

    assert_redirected_to user_custom_product_url(
      id: CustomProduct.last.id,
      user_id: CustomProduct.last.user.user_name.downcase
    )
  end

  test 'should show custom_product' do
    get user_custom_product_url(id: @custom_product.id, user_id: @custom_product.user.user_name.downcase)
    assert_response :success
  end

  test 'should get edit' do
    get dashboard_edit_custom_product_url(@custom_product)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    get dashboard_edit_custom_product_url(@custom_product)
    assert_response :success
  end

  test 'should update custom_product' do
    patch custom_product_url(@custom_product), params: { custom_product: {
      name: 'name'
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    patch custom_product_url(@custom_product), params: { custom_product: {
      name: 'name'
    } }
    assert_redirected_to user_custom_product_url(
      id: @custom_product.id,
      user_id: @custom_product.user.user_name.downcase
    )
  end

  test 'should destroy custom_product' do
    delete custom_product_url(@custom_product)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:with_everything)

    assert_difference('CustomProduct.count', -1) do
      delete custom_product_url(@custom_product)
    end

    assert_redirected_to dashboard_custom_products_url
  end
end
