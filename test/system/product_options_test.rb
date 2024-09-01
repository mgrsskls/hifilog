require "application_system_test_case"

class ProductOptionsTest < ApplicationSystemTestCase
  setup do
    @product_option = product_options(:one)
  end

  test "visiting the index" do
    visit product_options_url
    assert_selector "h1", text: "Product options"
  end

  test "should create product option" do
    visit product_options_url
    click_on "New product option"

    click_on "Create Product option"

    assert_text "Product option was successfully created"
    click_on "Back"
  end

  test "should update Product option" do
    visit product_option_url(@product_option)
    click_on "Edit this product option", match: :first

    click_on "Update Product option"

    assert_text "Product option was successfully updated"
    click_on "Back"
  end

  test "should destroy Product option" do
    visit product_option_url(@product_option)
    click_on "Destroy this product option", match: :first

    assert_text "Product option was successfully destroyed"
  end
end
