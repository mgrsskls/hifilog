require 'test_helper'

class SetupsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get dashboard_setups_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:visible)

    get dashboard_setups_path
    assert_response :success
  end

  test 'show' do
    get dashboard_setup_path(setups(:with_products))
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:without_anything)
    get dashboard_setup_path(setups(:with_products))
    assert_response :not_found

    sign_out users(:without_anything)

    sign_in users(:with_everything)
    get dashboard_setup_path(setups(:with_products))
    assert_response :success
    get dashboard_setup_path(setups(:without_products))
    assert_response :success
  end
end
