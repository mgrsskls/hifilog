# frozen_string_literal: true

require 'test_helper'

require 'securerandom'

class ProductVariantTest < ActiveSupport::TestCase
  include ApplicationHelper

  test 'formatted_discontinued_date' do
    product_variant = product_variants(:one)
    assert_nil product_variant.formatted_discontinued_date

    product_variant.update!(
      discontinued: true
    )
    assert_nil product_variant.formatted_discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020
    )
    assert_equal '2020', product_variant.formatted_discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020,
      discontinued_month: 12
    )
    assert_equal '2020/12', product_variant.formatted_discontinued_date

    product_variant.update!(
      discontinued: true,
      discontinued_year: 2020,
      discontinued_month: 12,
      discontinued_day: 31
    )
    assert_equal '2020/12/31', product_variant.formatted_discontinued_date
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

  test 'meta_desc uses the variant description when it has one' do
    product_variant = product_variants(:one)

    assert_equal 'MyText', product_variant.meta_desc
  end

  test 'meta_desc falls back to the parent product description' do
    product_variant = product_variants(:one)
    product_variant.update!(description: nil)
    product_variant.product.update!(description: 'Parent copy')

    assert_equal product_variant.product.meta_desc, product_variant.meta_desc
  end

  test 'meta_desc is generated from the variant data when no description exists anywhere' do
    product_variant = product_variants(:one)
    product_variant.update!(description: nil)
    product = product_variant.product

    copy = product_variant.meta_desc

    assert_includes copy, product.name
    assert_includes copy, product_variant.name_with_fallback
    assert_includes copy, product_variant.model_no
    assert_includes copy, product.brand.name
    assert_includes copy, 'Released in 2000.'
  end

  test 'meta_desc no longer leaves variant pages without a description' do
    product_variant = product_variants(:three)
    product_variant.update!(description: nil)

    assert_predicate product_variant.meta_desc, :present?
  end

  def real_products_count(brand)
    brand.products.count + ProductVariant.joins(:product).where(products: { brand_id: brand.id }).count
  end

  test 'creating a variant recalculates the brand products_count' do
    product = products(:one)
    brand = product.brand
    variant = ProductVariant.create!(name: "Counted #{SecureRandom.hex(4)}", product:, discontinued: false)

    assert_equal real_products_count(brand), brand.reload.products_count
  ensure
    variant&.destroy
  end

  test 'destroying a variant recalculates the brand products_count' do
    product = products(:one)
    brand = product.brand
    variant = ProductVariant.create!(name: "Counted #{SecureRandom.hex(4)}", product:, discontinued: false)

    variant.destroy

    assert_equal real_products_count(brand), brand.reload.products_count
  end

  test 'destroying a product cascades to its variants without breaking the brand products_count' do
    brand = brands(:one)
    product = Product.create!(
      name: "Counted #{SecureRandom.hex(4)}",
      brand:,
      sub_category_ids: [sub_categories(:one).id]
    )
    ProductVariant.create!(name: "Counted #{SecureRandom.hex(4)}", product:, discontinued: false)

    product.destroy

    assert_equal real_products_count(brand), brand.reload.products_count
  end
end
