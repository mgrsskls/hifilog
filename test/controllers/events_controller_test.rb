# frozen_string_literal: true

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

  test 'past canonical url is always year-specific when past events exist' do
    available_years = Event.available_past_years
    skip 'no past events' if available_years.empty?

    year = available_years.first
    get past_events_url
    assert_response :success
    assert_select 'link[rel="canonical"][href=?]', past_events_url(year:)

    get past_events_url(year:)
    assert_response :success
    assert_select 'link[rel="canonical"][href=?]', past_events_url(year:)
  end

  test 'events index has no noindex follow robots meta without filters' do
    get events_url
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'events index emits noindex follow when country filter applied' do
    get events_url(country: 'DE')
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end

  test 'past events without year or country params has no noindex follow robots meta' do
    get past_events_url
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'past events year filter is indexable without noindex robots meta' do
    available_years = Event.available_past_years
    skip 'no past events' if available_years.empty?

    get past_events_url(year: available_years.first)
    assert_select 'meta[name="robots"][content="noindex, follow"]', count: 0
  end

  test 'past events emits noindex follow when country filter applied' do
    get past_events_url(country: 'DE')
    assert_select 'meta[name="robots"][content=?]', 'noindex, follow'
  end
end
