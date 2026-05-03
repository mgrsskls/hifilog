# frozen_string_literal: true

require 'test_helper'

class EventAttendeesControllerTest < ActionDispatch::IntegrationTest
  test 'create registers attendance and redirects to events by default' do
    user = users(:one)
    event_attendees_count = user.event_attendees.count
    event = events(:two)

    post event_attendees_path(event_id: event.id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post event_attendees_path(event_id: event.id)

    assert_equal event_attendees_count + 1, user.event_attendees.count
    assert_response :redirect
    assert_redirected_to events_url(anchor: "event-#{event.id}")
  end

  test 'create redirects for redirect param dashboard paths' do
    user = users(:one)

    sign_in user

    [
      ['dashboard_bookmarks', :dashboard_bookmarks_url],
      ['dashboard_events', :dashboard_events_url],
      ['dashboard_past_events', :dashboard_past_events_url],
      ['past_events', :past_events_url]
    ].each do |redirect_param, url_helper|
      event = Event.create!(
        name: "Redirect test #{SecureRandom.hex(4)}",
        address: 'x',
        url: 'https://example.test/redir',
        country_code: 'US',
        start_date: Time.zone.today + 360,
        end_date: Time.zone.today + 361
      )

      post event_attendees_path(event_id: event.id, redirect: redirect_param)

      assert_redirected_to send(url_helper, anchor: "event-#{event.id}")
    end
  end

  test 'destroy removes attendance' do
    user = users(:one)
    event_attendee = user.event_attendees.first
    event_attendees_count = user.event_attendees.count

    delete event_attendee_path(event_attendee)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete event_attendee_path(event_attendee)

    assert_equal event_attendees_count - 1, user.event_attendees.count
    assert_response :redirect
    assert_redirected_to events_url
  end

  test 'destroy uses past flash variant when past flag set' do
    user = users(:one)
    event_attendee = user.event_attendees.first
    event = event_attendee.event

    sign_in user

    delete event_attendee_path(event_attendee), params: { past: 'true' }

    expected = I18n.t('event_attendee.messages.destroyed.past', name: event.name)
    assert_equal expected, flash[:notice]
  end

  test 'destroy redirects for redirect param without anchor' do
    user = users(:one)
    event = events(:three)

    sign_in user

    post event_attendees_path(event_id: event.id)
    attendee = user.event_attendees.find_by!(event_id: event.id)

    delete event_attendee_path(attendee), params: { redirect: 'dashboard_bookmarks' }
    assert_redirected_to dashboard_bookmarks_url

    post event_attendees_path(event_id: event.id)
    attendee = user.event_attendees.find_by!(event_id: event.id)

    delete event_attendee_path(attendee), params: { redirect: 'dashboard_events' }
    assert_redirected_to dashboard_events_url

    post event_attendees_path(event_id: event.id)
    attendee = user.event_attendees.find_by!(event_id: event.id)

    delete event_attendee_path(attendee), params: { redirect: 'dashboard_past_events' }
    assert_redirected_to dashboard_past_events_url

    post event_attendees_path(event_id: event.id)
    attendee = user.event_attendees.find_by!(event_id: event.id)

    delete event_attendee_path(attendee), params: { redirect: 'past_events' }
    assert_redirected_to past_events_url
  end
end
