# frozen_string_literal: true

require 'test_helper'

class DiscontinuedDateTest < ActiveSupport::TestCase
  test 'returns nil when product is active' do
    assert_not products(:one).discontinued

    assert_nil products(:one).discontinued_date
  end

  test 'returns nil when marked discontinued without date components' do
    product = products(:discontinued)

    assert product.discontinued
    assert_nil product.discontinued_date
  end

  test 'computes discontinued_date from components when discontinued' do
    product = products(:discontinued)
    product.assign_attributes(discontinued_year: 2021, discontinued_month: 3, discontinued_day: 15)

    assert_equal Date.new(2021, 3, 15), product.discontinued_date
  end
end
