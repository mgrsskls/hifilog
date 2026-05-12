# frozen_string_literal: true

require 'test_helper'

class EventAttendeesControllerTest < ActionDispatch::IntegrationTest
  test 'create registers attendance and redirects to event page' do
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
    assert_redirected_to event_url(year: event.calendar_year, slug: event.friendly_id)
  end

  test 'create without event_id redirects to events index' do
    sign_in users(:one)

    post event_attendees_path

    assert_redirected_to events_url
    assert_equal I18n.t(:generic_error_message), flash[:alert]
  end

  test 'destroy removes attendance' do
    user = users(:one)
    event_attendee = user.event_attendees.first
    event = event_attendee.event
    event_attendees_count = user.event_attendees.count

    delete event_attendee_path(event_attendee)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    delete event_attendee_path(event_attendee)

    assert_equal event_attendees_count - 1, user.event_attendees.count
    assert_response :redirect
    assert_redirected_to event_url(year: event.calendar_year, slug: event.friendly_id)
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
end
