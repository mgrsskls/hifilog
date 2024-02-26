require 'test_helper'

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test 'index for logged out user' do
    get root_url
    assert_response :success
  end

  test 'index for logged in user redirects to dashboard' do
    sign_in users(:hidden)
    get root_url
    assert_response :redirect
    assert_redirected_to dashboard_root_path
  end
end
