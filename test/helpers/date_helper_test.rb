# frozen_string_literal: true

require 'test_helper'

class DateHelperTest < ActionView::TestCase
  test 'single date formats with day and year' do
    d = Time.zone.local(2024, 3, 5, 12, 0, 0)
    assert_equal 'March 5, 2024', humanize_date_range(d)
  end

  test 'range spans years with both years shown' do
    from = Time.zone.local(2023, 12, 1)
    to = Time.zone.local(2024, 1, 15)
    assert_equal 'December 1, 2023 – January 15, 2024', humanize_date_range(from, to)
  end

  test 'range same year different months omits repeated year on start' do
    from = Time.zone.local(2024, 1, 10)
    to = Time.zone.local(2024, 2, 2)
    assert_equal 'January 10 – February 2, 2024', humanize_date_range(from, to)
  end

  test 'range same month joins day span' do
    from = Time.zone.local(2024, 5, 1)
    to = Time.zone.local(2024, 5, 7)
    assert_equal 'May 1–7, 2024', humanize_date_range(from, to)
  end

  test 'same day collapses to a single formatted date' do
    day = Time.zone.local(2022, 7, 4)
    assert_equal 'July 4, 2022', humanize_date_range(day, day)
  end
end
