# frozen_string_literal: true

require 'test_helper'

class FormatTest < ActiveSupport::TestCase
  test 'formats partial dates on Product' do
    assert_equal '2020/06/01', products(:release_date_ymd).formatted_release_date
    assert_equal '2020/06', products(:release_date_ym).formatted_release_date
    assert_equal '2020', products(:release_date_yd).formatted_release_date # release_month nil short-circuits display
    assert_equal '2020', products(:release_date_y).formatted_release_date
  end

  test 'formats founded and discontinued timestamps on Brand' do
    brand = brands(:one)
    brand.assign_attributes(founded_year: 1985, founded_month: 9, founded_day: 30)
    brand.assign_attributes(discontinued_year: 2022, discontinued_month: nil, discontinued_day: nil)

    assert_equal '1985/09/30', brand.formatted_founded_date
    assert_equal '2022', brand.formatted_discontinued_date
  end
end
