# frozen_string_literal: true

require 'test_helper'

class DatePartsValidatableTest < ActiveSupport::TestCase
  test 'rejects release day outside calendar range' do
    product = products(:release_date_ymd)
    product.release_day = 32

    assert_not product.valid?
    assert product.errors[:release_day].any?
  end

  test 'rejects release month outside calendar range' do
    product = products(:release_date_ymd)
    product.release_month = 13

    assert_not product.valid?
    assert product.errors[:release_month].any?
  end

  test 'rejects release year before supported lower bound' do
    product = products(:release_date_ymd)
    product.release_year = 1800

    assert_not product.valid?
    assert product.errors[:release_year].any?
  end
end
