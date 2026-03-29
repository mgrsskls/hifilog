# frozen_string_literal: true

require 'test_helper'

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  test 'current' do
    get dashboard_statistics_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_statistics_root_path
    assert_response :success
  end

  test 'total' do
    get dashboard_statistics_total_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_statistics_total_path
    assert_response :success
  end

  test 'yearly' do
    get dashboard_statistics_yearly_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_statistics_yearly_path
    assert_response :success
  end
end
