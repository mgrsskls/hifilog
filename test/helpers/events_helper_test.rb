# frozen_string_literal: true

require 'test_helper'

class EventsHelperTest < ActionView::TestCase
  include ApplicationHelper

  delegate :params, to: :controller

  test 'events_index_item_list_json_ld describes upcoming list' do
    events_scope = [events(:two)]
    active_events = :upcoming
    canonical_url = 'https://www.example.com/events'
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/events')

    json = events_index_item_list_json_ld(
      events: events_scope,
      meta_desc: nil,
      active_events:,
      canonical_url:
    )

    assert_equal 'ItemList', json['@type']
    assert_equal 'Upcoming Hi-Fi Events & Shows', json['name']
    assert_equal 1, json['numberOfItems']
    assert_equal 'https://schema.org/ItemListOrderAscending', json['itemListOrder']
    assert_equal 'https://www.example.com/events', json['url']
    assert_not_includes json.keys, 'description'

    li = json['itemListElement'].first
    assert_equal 'ListItem', li['@type']
    assert_equal 1, li['position']
    assert_equal 'Event', li['item']['@type']
    assert_equal events(:two).name, li['item']['name']
    assert_equal 'https://www.example.com', li['item']['url']
  end

  test 'events_index_item_list_json_ld describes past list with descending order' do
    events_scope = [events(:one)]
    canonical_url = 'https://www.example.com/events/past?year=2020'
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/events/past?year=2020')

    json = events_index_item_list_json_ld(
      events: events_scope,
      meta_desc: nil,
      active_events: :past,
      canonical_url:
    )

    assert_equal 'Past Hi-Fi Events & Shows', json['name']
    assert_equal 'https://schema.org/ItemListOrderDescending', json['itemListOrder']
    assert_equal canonical_url, json['url']
  end

  test 'events_index_item_list_json_ld squish meta description into description' do
    canonical_url = 'https://www.example.com/events'
    meta_desc = "  Find all events \n  "
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/events')

    json = events_index_item_list_json_ld(
      events: [],
      meta_desc:,
      active_events: :upcoming,
      canonical_url:
    )

    assert_equal 'Find all events', json['description']
  end

  test 'events_index_item_list_json_ld event without url uses canonical fragment' do
    event = Event.new(
      name: 'No URL Event',
      start_date: Date.new(2030, 1, 1),
      end_date: Date.new(2030, 1, 2),
      country_code: 'US',
      address: 'Somewhere',
      slug: 'no-url-event',
      calendar_year: 2030
    )
    event.id = 99_001

    events_scope = [event]
    canonical_url = 'https://www.example.com/events'
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/events')

    json = events_index_item_list_json_ld(
      events: events_scope,
      meta_desc: nil,
      active_events: :upcoming,
      canonical_url:
    )

    assert_equal 'https://www.example.com/events/2030/no-url-event', json['itemListElement'].first['item']['url']
  end

  test 'events_index_item_list_json_ld falls back to request URL when canonical URL is omitted' do
    controller.params = ActionController::Parameters.new
    replace_request_env!('https://www.example.com/events?country=DE')

    json = events_index_item_list_json_ld(
      events: [],
      meta_desc: nil,
      active_events: :upcoming
    )

    assert_equal 'https://www.example.com/events?country=DE', json['url']
  end
end
