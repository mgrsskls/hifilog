require 'test_helper'

class EventsControllerTest < ActionDispatch::IntegrationTest
  test 'index' do
    get events_url
    assert_response :success
  end

  test 'index with country filter' do
    get events_url(country: 'DE')
    assert_response :success
  end

  test 'past' do
    get past_events_url
    assert_response :success
  end

  test 'past with year filter' do
    available_years = Event.available_past_years
    if available_years.any?
      get past_events_url(year: available_years.first)
      assert_response :success
    end
  end

  test 'past with country filter' do
    get past_events_url(country: 'DE')
    assert_response :success
  end
end
