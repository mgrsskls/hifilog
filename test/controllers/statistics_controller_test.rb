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
    assert_equal '/dashboard/insights', path
  end

  test 'legacy statistics paths redirect to insights' do
    sign_in users(:one)

    get '/dashboard/statistics'
    assert_redirected_to '/dashboard/insights'

    get '/dashboard/statistics/total'
    assert_redirected_to '/dashboard/insights/total'

    get '/dashboard/statistics/yearly'
    assert_redirected_to '/dashboard/insights/yearly'
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
