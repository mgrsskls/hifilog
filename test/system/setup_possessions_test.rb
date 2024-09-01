require "application_system_test_case"

class SetupPossessionsTest < ApplicationSystemTestCase
  setup do
    @setup_possession = setup_possessions(:one)
  end

  test "visiting the index" do
    visit setup_possessions_url
    assert_selector "h1", text: "Setup possessions"
  end

  test "should create setup possession" do
    visit setup_possessions_url
    click_on "New setup possession"

    click_on "Create Setup possession"

    assert_text "Setup possession was successfully created"
    click_on "Back"
  end

  test "should update Setup possession" do
    visit setup_possession_url(@setup_possession)
    click_on "Edit this setup possession", match: :first

    click_on "Update Setup possession"

    assert_text "Setup possession was successfully updated"
    click_on "Back"
  end

  test "should destroy Setup possession" do
    visit setup_possession_url(@setup_possession)
    click_on "Destroy this setup possession", match: :first

    assert_text "Setup possession was successfully destroyed"
  end
end
