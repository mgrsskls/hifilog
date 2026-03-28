require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test 'past scope' do
    past_events = Event.past
    assert(past_events.all? do |e|
      (e.end_date.present? && e.end_date < Time.zone.today) || e.start_date < Time.zone.today
    end)
  end

  test 'upcoming scope' do
    upcoming_events = Event.upcoming
    assert(upcoming_events.all? do |e|
      (e.end_date.present? && e.end_date >= Time.zone.today) || e.start_date >= Time.zone.today
    end)
  end

  test 'by_year scope' do
    year = 2024
    events = Event.by_year(year)
    assert(events.all? { |e| e.start_date.year == year })
  end

  test 'available_past_years' do
    years = Event.available_past_years
    assert years.is_a?(Array)
    assert(years.all?(Integer))
    assert years == years.sort.reverse
  end

  test 'discontinued?' do
    event = Event.new
    event.start_date = 1.day.ago
    event.end_date = 1.day.ago
    assert event.discontinued?

    event.end_date = 1.day.from_now
    assert_not event.discontinued?

    event.end_date = nil
    event.start_date = 1.day.ago
    assert event.discontinued?
  end

  test 'cached_past_count' do
    count = Event.cached_past_count
    assert_equal Event.past.count, count
  end

  test 'cached_upcoming_count' do
    count = Event.cached_upcoming_count
    assert_equal Event.upcoming.count, count
  end
end
