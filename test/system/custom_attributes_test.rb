require "application_system_test_case"

class CustomAttributesTest < ApplicationSystemTestCase
  setup do
    @custom_attribute = custom_attributes(:one)
  end

  test "visiting the index" do
    visit custom_attributes_url
    assert_selector "h1", text: "Custom attributes"
  end

  test "should create custom attribute" do
    visit custom_attributes_url
    click_on "New custom attribute"

    click_on "Create Custom attribute"

    assert_text "Custom attribute was successfully created"
    click_on "Back"
  end

  test "should update Custom attribute" do
    visit custom_attribute_url(@custom_attribute)
    click_on "Edit this custom attribute", match: :first

    click_on "Update Custom attribute"

    assert_text "Custom attribute was successfully updated"
    click_on "Back"
  end

  test "should destroy Custom attribute" do
    visit custom_attribute_url(@custom_attribute)
    click_on "Destroy this custom attribute", match: :first

    assert_text "Custom attribute was successfully destroyed"
  end
end
