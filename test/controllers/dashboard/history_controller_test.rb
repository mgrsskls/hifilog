# frozen_string_literal: true

require 'test_helper'

class Dashboard::HistoryControllerTest < ActionDispatch::IntegrationTest
  test 'history' do
    get dashboard_history_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_history_path
    assert_response :success
  end
end
