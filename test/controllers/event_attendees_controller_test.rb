require 'test_helper'

class EventAttendeesControllerTest < ActionDispatch::IntegrationTest
  test 'create' do
    user = users(:one)
    event_attendees_count = user.event_attendees.count
    event = Event.first

    post event_attendees_path(event_id: event.id)
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in user

    post event_attendees_path(event_id: event.id)

    assert_equal event_attendees_count + 1, Bookmark.where(user_id: user.id).count
    assert_response :redirect
    assert_redirected_to events_url(anchor: "event-#{event.id}")
  end

  test 'destroy' do
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
end
