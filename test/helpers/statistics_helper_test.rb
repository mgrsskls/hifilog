# frozen_string_literal: true

require 'test_helper'

class StatisticsHelperTest < ActionView::TestCase
  test 'current_overview_statistics' do
    stats = current_overview_statistics(
      products_count: 3,
      brands_count: 2,
      spendings: [{ currency: 'EUR', spendings: 1234.56 }]
    )

    assert_equal 3, stats[0][:value]
    assert_equal 'You currently own', stats[0][:label]
    assert_equal 2, stats[1][:value]
    assert_equal '1,235', stats[2][:value]
    assert_equal 'EUR', stats[2][:unit]
  end

  test 'current_overview_statistics without spendings' do
    stats = current_overview_statistics(
      products_count: 0,
      brands_count: 0,
      spendings: []
    )

    assert_equal 0, stats[2][:value]
    assert_equal 'n/a', stats[2][:unit]
  end
end
