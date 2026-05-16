# frozen_string_literal: true

require 'test_helper'

class EventAttendeeTest < ActiveSupport::TestCase
  test 'counts_for returns attendee counts keyed by event id' do
    event = events(:one)
    assert_equal({ event.id => 1 }, EventAttendee.counts_for([event.id]))
    assert_equal({}, EventAttendee.counts_for([]))
    assert_equal({}, EventAttendee.counts_for(nil))
  end

  test 'duplicate user for the same event is invalid' do
    duplicate = EventAttendee.new(
      user: users(:one),
      event: events(:one)
    )

    assert_not duplicate.valid?

    attendee = EventAttendee.new(user: users(:visible), event: events(:one))
    assert_predicate attendee, :valid?
  end
end
