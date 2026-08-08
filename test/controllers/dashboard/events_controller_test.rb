# frozen_string_literal: true

require 'test_helper'

class Dashboard::EventsControllerTest < ActionDispatch::IntegrationTest
  test 'events' do
    get dashboard_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_events_path
    assert_response :success

    get dashboard_events_path(country: 'DE')
    assert_response :success
  end

  test 'past_events' do
    get dashboard_past_events_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)

    get dashboard_past_events_path
    assert_response :success

    get dashboard_past_events_path(year: Time.zone.today.year)
    assert_response :success
  end
end
