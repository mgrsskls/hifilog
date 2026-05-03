# frozen_string_literal: true

require 'test_helper'

require 'base64'

class CustomProductsControllerTest < ActionDispatch::IntegrationTest
  test 'index without custom products' do
    user = users(:one)

    get dashboard_custom_products_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user
    user.custom_products.destroy_all
    assert_equal user.custom_products.count, 0

    get dashboard_custom_products_url
    assert_response :success
  end

  test 'index with custom products' do
    user = users(:one)

    get dashboard_custom_products_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user
    assert_equal 3, user.custom_products.count

    get dashboard_custom_products_url
    assert_response :success
  end

  test 'should get new' do
    get dashboard_new_custom_product_url
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_new_custom_product_url
    assert_response :success
  end

  test 'should create custom_product' do
    user = users(:one)
    custom_products_count = user.custom_products.count

    post custom_products_url, params: { custom_product: {
      name: 'Custom Product',
      sub_category_ids: [
        sub_categories(:one).id,
        sub_categories(:two).id
      ]
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    assert_difference('CustomProduct.count') do
      post custom_products_url, params: { custom_product: {
        name: 'Custom Product',
        sub_category_ids: [
          sub_categories(:one).id,
          sub_categories(:two).id
        ]
      } }
    end
    assert_equal user.custom_products.count, custom_products_count + 1
    assert_redirected_to user_custom_product_url(
      id: CustomProduct.last.id,
      user_id: CustomProduct.last.user.user_name.downcase
    )
  end

  test 'should show custom_product' do
    user = users(:one)
    custom_product = custom_products(:one)

    # custom product belongs to public user
    # owned by user
    user.update!(profile_visibility: 2)
    get user_custom_product_url(id: custom_product.id, user_id: custom_product.user.user_name.downcase)
    assert_response :success

    # not owned by user
    get user_custom_product_url(id: custom_products(:three).id, user_id: custom_product.user.user_name.downcase)
    assert_response :success

    # custom product belongs to hidden user
    user.update!(profile_visibility: 0)
    get user_custom_product_url(id: custom_product.id, user_id: custom_product.user.user_name.downcase)
    assert_response :redirect
    assert_redirected_to root_url

    # custom product belongs to user only visible logged in
    user.update!(profile_visibility: 1)
    get user_custom_product_url(id: custom_product.id, user_id: custom_product.user.user_name.downcase)
    assert_response :redirect
    assert_redirected_to new_user_session_path(
      redirect: user_custom_product_path(id: custom_product.id, user_id: custom_product.user.user_name.downcase)
    )

    # … and user is the same
    sign_in user
    get user_custom_product_url(id: custom_product.id, user_id: custom_product.user.user_name.downcase)
    assert_response :success
  end

  test 'should get edit' do
    custom_product = custom_products(:one)

    get dashboard_edit_custom_product_url(custom_product)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_edit_custom_product_url(custom_product)
    assert_response :success
  end

  test 'should update custom_product' do
    custom_product = custom_products(:one)
    name = 'new name'

    patch custom_product_url(custom_product), params: { custom_product: {
      name:
    } }
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    patch custom_product_url(custom_product), params: { custom_product: {
      name:
    } }
    assert_equal name, CustomProduct.find(custom_product.id).name
    assert_redirected_to user_custom_product_url(
      id: custom_product.id,
      user_id: custom_product.user.user_name.downcase
    )
  end

  test 'should destroy custom_product' do
    custom_product = custom_products(:one)

    delete custom_product_url(custom_product)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    assert_difference('CustomProduct.count', -1) do
      delete custom_product_url(custom_product)
    end

    assert_redirected_to dashboard_custom_products_url
  end

  test 'create with missing name renders validation errors' do
    sign_in users(:one)

    assert_no_difference('CustomProduct.count') do
      post custom_products_url, params: {
        custom_product: {
          name: '',
          sub_category_ids: [sub_categories(:one).id]
        }
      }
    end

    assert_response :unprocessable_content
  end

  test 'update clears highlighted image when flagged for removal' do
    custom_product = custom_products(:three)
    pixel = Base64.decode64(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    )

    custom_product.images.purge if custom_product.images.attached?
    custom_product.images.attach(
      io: StringIO.new(pixel),
      filename: 'hero.png',
      content_type: 'image/png'
    )
    attachment = custom_product.images.first
    custom_product.update!(highlighted_image_id: attachment.id)

    sign_in users(:one)

    patch custom_product_url(custom_product), params: {
      custom_product: {
        name: custom_product.name,
        sub_category_ids: custom_product.sub_categories.map(&:id),
        highlighted_image_id: attachment.id
      },
      delete_image: [attachment.id.to_s]
    }

    assert_response :redirect
    assert_nil custom_product.reload.highlighted_image_id
    assert_not custom_product.images.attached?
  ensure
    custom_product&.images&.purge
    custom_product&.update!(highlighted_image_id: nil)
  end
end
