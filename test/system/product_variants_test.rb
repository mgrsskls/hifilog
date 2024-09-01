require "application_system_test_case"

class ProductVariantsTest < ApplicationSystemTestCase
  setup do
    @product_variant = product_variants(:one)
  end

  test "visiting the index" do
    visit product_variants_url
    assert_selector "h1", text: "Product variants"
  end

  test "should create product variant" do
    visit product_variants_url
    click_on "New product variant"

    click_on "Create Product variant"

    assert_text "Product variant was successfully created"
    click_on "Back"
  end

  test "should update Product variant" do
    visit product_variant_url(@product_variant)
    click_on "Edit this product variant", match: :first

    click_on "Update Product variant"

    assert_text "Product variant was successfully updated"
    click_on "Back"
  end

  test "should destroy Product variant" do
    visit product_variant_url(@product_variant)
    click_on "Destroy this product variant", match: :first

    assert_text "Product variant was successfully destroyed"
  end
end
