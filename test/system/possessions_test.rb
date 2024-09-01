require "application_system_test_case"

class PossessionsTest < ApplicationSystemTestCase
  setup do
    @possession = possessions(:one)
  end

  test "visiting the index" do
    visit possessions_url
    assert_selector "h1", text: "Possessions"
  end

  test "should create possession" do
    visit possessions_url
    click_on "New possession"

    click_on "Create Possession"

    assert_text "Possession was successfully created"
    click_on "Back"
  end

  test "should update Possession" do
    visit possession_url(@possession)
    click_on "Edit this possession", match: :first

    click_on "Update Possession"

    assert_text "Possession was successfully updated"
    click_on "Back"
  end

  test "should destroy Possession" do
    visit possession_url(@possession)
    click_on "Destroy this possession", match: :first

    assert_text "Possession was successfully destroyed"
  end
end
