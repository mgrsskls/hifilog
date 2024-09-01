require "test_helper"

class CustomProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @custom_product = custom_products(:one)
  end

  test "should get index" do
    get custom_products_url
    assert_response :success
  end

  test "should get new" do
    get new_custom_product_url
    assert_response :success
  end

  test "should create custom_product" do
    assert_difference("CustomProduct.count") do
      post custom_products_url, params: { custom_product: {} }
    end

    assert_redirected_to custom_product_url(CustomProduct.last)
  end

  test "should show custom_product" do
    get custom_product_url(@custom_product)
    assert_response :success
  end

  test "should get edit" do
    get edit_custom_product_url(@custom_product)
    assert_response :success
  end

  test "should update custom_product" do
    patch custom_product_url(@custom_product), params: { custom_product: {} }
    assert_redirected_to custom_product_url(@custom_product)
  end

  test "should destroy custom_product" do
    assert_difference("CustomProduct.count", -1) do
      delete custom_product_url(@custom_product)
    end

    assert_redirected_to custom_products_url
  end
end
