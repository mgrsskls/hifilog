# frozen_string_literal: true

require 'test_helper'

class Dashboard::ContributionsControllerTest < ActionDispatch::IntegrationTest
  test 'contributions' do
    get dashboard_contributions_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_contributions_path
    assert_response :success
  end
end
