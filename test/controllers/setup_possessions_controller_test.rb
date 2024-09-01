require "test_helper"

class SetupPossessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @setup_possession = setup_possessions(:one)
  end

  test "should get index" do
    get setup_possessions_url
    assert_response :success
  end

  test "should get new" do
    get new_setup_possession_url
    assert_response :success
  end

  test "should create setup_possession" do
    assert_difference("SetupPossession.count") do
      post setup_possessions_url, params: { setup_possession: {} }
    end

    assert_redirected_to setup_possession_url(SetupPossession.last)
  end

  test "should show setup_possession" do
    get setup_possession_url(@setup_possession)
    assert_response :success
  end

  test "should get edit" do
    get edit_setup_possession_url(@setup_possession)
    assert_response :success
  end

  test "should update setup_possession" do
    patch setup_possession_url(@setup_possession), params: { setup_possession: {} }
    assert_redirected_to setup_possession_url(@setup_possession)
  end

  test "should destroy setup_possession" do
    assert_difference("SetupPossession.count", -1) do
      delete setup_possession_url(@setup_possession)
    end

    assert_redirected_to setup_possessions_url
  end
end
