require 'test_helper'

class ProductTest < ActiveSupport::TestCase
  test 'release_date' do
    assert_equal products(:release_date_ymd).release_date, '01/06/2020'
    assert_equal products(:release_date_ym).release_date, '06/2020'
    assert_equal products(:release_date_yd).release_date, '2020'
    assert_nil products(:release_date_md).release_date
    assert_equal products(:release_date_y).release_date, '2020'
    assert_nil products(:release_date_m).release_date
    assert_nil products(:release_date_d).release_date
  end
end
