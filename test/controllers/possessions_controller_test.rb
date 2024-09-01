require "test_helper"

class PossessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @possession = possessions(:one)
  end

  test "should get index" do
    get possessions_url
    assert_response :success
  end

  test "should get new" do
    get new_possession_url
    assert_response :success
  end

  test "should create possession" do
    assert_difference("Possession.count") do
      post possessions_url, params: { possession: {} }
    end

    assert_redirected_to possession_url(Possession.last)
  end

  test "should show possession" do
    get possession_url(@possession)
    assert_response :success
  end

  test "should get edit" do
    get edit_possession_url(@possession)
    assert_response :success
  end

  test "should update possession" do
    patch possession_url(@possession), params: { possession: {} }
    assert_redirected_to possession_url(@possession)
  end

  test "should destroy possession" do
    assert_difference("Possession.count", -1) do
      delete possession_url(@possession)
    end

    assert_redirected_to possessions_url
  end
end
