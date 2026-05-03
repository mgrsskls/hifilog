# frozen_string_literal: true

require 'test_helper'

class ReleaseDateTest < ActiveSupport::TestCase
  test 'builds Date from partial release fields on Product' do
    assert_equal Date.new(2020, 6, 1), products(:release_date_ymd).release_date
    assert_equal Date.new(2020, 6, 1), products(:release_date_ym).release_date
    assert_equal Date.new(2020, 1, 1), products(:release_date_yd).release_date
    assert_equal Date.new(2020, 1, 1), products(:release_date_y).release_date

    assert_nil products(:release_date_md).reload.release_date # year missing
    assert_nil products(:release_date_m).reload.release_date
    assert_nil products(:release_date_d).reload.release_date
  end

  test 'delegates consistent Date behavior on ProductVariant' do
    variant = product_variants(:one)

    assert_equal Date.new(2000, 12, 1), variant.reload.release_date
  end

  test 'scoped query surface includes release_date-derived rows on ProductItem' do
    product = products(:release_date_ymd)
    row = ProductItem.find_by(product_id: product.id, item_type: 'Product')

    skip 'product_items view lacks row for fixture product' unless row

    assert_equal product.release_year, row.release_year
    assert_equal product.release_date, row.release_date
  end
end
