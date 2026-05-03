# frozen_string_literal: true

require 'test_helper'

class DashboardNavigationTest < ActionDispatch::IntegrationTest
  test 'authenticated users traverse primary dashboard hubs' do
    sign_in users(:visible)

    get dashboard_root_path
    assert_response :success

    get dashboard_products_path
    assert_response :success

    get dashboard_bookmarks_path
    assert_response :success

    get dashboard_statistics_root_path
    assert_response :success

    get dashboard_custom_products_path
    assert_response :success

    get dashboard_setups_path
    assert_response :success

    get dashboard_notes_path
    assert_response :success
  end
end
