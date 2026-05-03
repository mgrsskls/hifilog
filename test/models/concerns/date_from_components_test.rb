# frozen_string_literal: true

require 'test_helper'

class DateFromComponentsTest < ActiveSupport::TestCase
  test 'returns Date when only year present' do
    brand = brands(:one)

    assert_equal Date.new(2000, 1, 1), brand.date_from_components(2000, nil, nil)
  end

  test 'returns Date when year and month present' do
    brand = brands(:one)

    assert_equal Date.new(2020, 6, 1), brand.date_from_components(2020, 6, nil)
  end

  test 'returns full Date when all parts present' do
    brand = brands(:one)

    assert_equal Date.new(2020, 6, 15), brand.date_from_components(2020, 6, 15)
  end

  test 'returns nil when year blank' do
    brand = brands(:one)

    assert_nil brand.date_from_components(nil, 6, 15)
    assert_nil brand.date_from_components('', 6, 15)
  end
end
