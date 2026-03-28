require 'test_helper'

class PossessionTest < ActiveSupport::TestCase
  test 'brand delegation for product' do
    possession = possessions(:current_product)
    assert_equal possession.product.brand, possession.brand
  end

  test 'brand delegation for product variant' do
    possession = possessions(:current_product_variant)
    assert_equal possession.product_variant.product.brand, possession.brand
  end

  test 'brand for custom product' do
    possession = possessions(:current_custom_product)
    assert_nil possession.brand
  end

  test 'year_of_purchase' do
    possession = Possession.new(product: products(:one), user: users(:one))
    assert_nil possession.year_of_purchase

    possession.update!(period_from: Date.new(2020, 6, 15))
    assert_equal 2020, possession.year_of_purchase
  end

  test 'duration for current possession' do
    possession = possessions(:current_product)
    possession.update!(period_from: 30.days.ago)
    duration = possession.duration
    assert duration > 28 * 86_400 # More than 28 days in seconds
    assert duration < 31 * 86_400 # Less than 31 days in seconds
  end

  test 'duration for previous possession' do
    possession = possessions(:prev_product)
    assert_nil possession.duration if possession.period_to.blank?

    # Freeze time at the start of a specific second
    # otherwise, the duration may be off by a few seconds due to the time taken to execute the code
    travel_to Time.zone.local(2026, 3, 28, 12, 0, 0) do
      possession.update!(period_from: 100.days.ago, period_to: 50.days.ago)

      duration = possession.duration
      assert_equal 50.days.to_i, duration
    end
  end
end
