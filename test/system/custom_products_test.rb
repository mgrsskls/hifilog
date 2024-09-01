require "application_system_test_case"

class CustomProductsTest < ApplicationSystemTestCase
  setup do
    @custom_product = custom_products(:one)
  end

  test "visiting the index" do
    visit custom_products_url
    assert_selector "h1", text: "Custom products"
  end

  test "should create custom product" do
    visit custom_products_url
    click_on "New custom product"

    click_on "Create Custom product"

    assert_text "Custom product was successfully created"
    click_on "Back"
  end

  test "should update Custom product" do
    visit custom_product_url(@custom_product)
    click_on "Edit this custom product", match: :first

    click_on "Update Custom product"

    assert_text "Custom product was successfully updated"
    click_on "Back"
  end

  test "should destroy Custom product" do
    visit custom_product_url(@custom_product)
    click_on "Destroy this custom product", match: :first

    assert_text "Custom product was successfully destroyed"
  end
end
