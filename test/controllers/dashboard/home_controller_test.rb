# frozen_string_literal: true

require 'test_helper'

class Dashboard::HomeControllerTest < ActionDispatch::IntegrationTest
  test 'dashboard' do
    get dashboard_root_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_root_path
    assert_response :success
    assert_select '.UserDashboard-feed'
    assert_select '.UserDashboard-statistics .StatisticsNumbers'
    assert_match 'You currently own', @response.body
    assert_select '.UserDashboard-events'
    assert_select '.UserDashboard-newest'
    assert_select 'a[href=?]', dashboard_feed_path
    assert_select 'a[href=?]', dashboard_statistics_root_path
  end
end
