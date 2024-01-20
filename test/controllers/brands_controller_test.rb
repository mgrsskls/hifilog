require "test_helper"

class BrandsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get brands_url
    assert_response :success
  end

  test "should get show" do
    get brand_url(id: "feliks-audio")
    assert_response :success
  end
end
