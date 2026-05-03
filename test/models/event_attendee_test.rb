# frozen_string_literal: true

require 'test_helper'

class EventAttendeeTest < ActiveSupport::TestCase
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
