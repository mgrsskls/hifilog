require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get categories_url
    assert_response :success
  end

  test "should get show" do
    get category_url(id: "amplifiers")
    assert_response :success
  end
end
