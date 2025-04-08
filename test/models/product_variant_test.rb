require 'test_helper'

class ProductVariantTest < ActiveSupport::TestCase
  include ApplicationHelper

  test 'discontinued_date' do
    product_variant = product_variants(:one)
    assert_nil product_variant.discontinued_date

    product_variant.update!(
      discontinued: true,
    )
    assert_nil product_variant.discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020
    )
    assert_equal '2020', product_variant.discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020,
      discontinued_month: 12
    )
    assert_equal '12/2020', product_variant.discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020,
      discontinued_month: 12,
      discontinued_day: 31
    )
    assert_equal '31/12/2020', product_variant.discontinued_date
  end

  test 'name_with_fallback' do
    product_variant = product_variants(:one)

    assert_equal product_variant.name, product_variant.name_with_fallback

    product_variant.update!(name: nil)

    assert_equal 'Update', product_variant.name_with_fallback
  end

  test 'short_name' do
    product_variant = product_variants(:one)

    assert_equal product_variant.name_with_fallback, product_variant.short_name
  end

  test 'display_name' do
    product_variant = product_variants(:one)

    assert_equal 'ZMF Atrium Closed LTD 2024', product_variant.display_name
  end

  test 'display_price' do
    assert_equal '9,999.00 USD', display_price(product_variants(:one).price, product_variants(:one).price_currency)
  end

  test 'formatted_description' do
    product_variant = product_variants(:one)

    assert_equal '<p>MyText</p>', product_variant.formatted_description.strip

    product_variant.update!(description: nil)

    assert_nil product_variant.formatted_description
  end
end
