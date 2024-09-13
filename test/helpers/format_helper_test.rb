require 'test_helper'

class FormatHelperTest < ActionView::TestCase
  test 'formatted_date' do
    assert_equal formatted_date(Time.zone.local(2000, 1, 1)), '2000-01-01T00:00+0000'
  end

  test 'formatted_datetime' do
    assert_equal formatted_datetime(Time.zone.local(2000, 1, 1, 12, 30)), '2000-01-01T12:30+0000'
  end
end
