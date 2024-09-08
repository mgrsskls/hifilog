require 'test_helper'

class SetupsControllerTest < ActionDispatch::IntegrationTest
  test 'changelog' do
    get changelog_path
    assert_response :success
  end

  test 'about' do
    get about_path
    assert_response :success
  end

  test 'imprint' do
    get imprint_path
    assert_response :success
  end

  test 'privacy_policy' do
    get privacy_policy_path
    assert_response :success
  end
end
