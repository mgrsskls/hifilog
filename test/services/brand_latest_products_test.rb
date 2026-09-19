# frozen_string_literal: true

require 'test_helper'

class BrandLatestProductsTest < ActiveSupport::TestCase
  setup do
    @brand = Brand.create!(name: "Latest Products #{SecureRandom.hex(3)}", country_code: 'US', discontinued: false)
    @first = ProductSeries.create!(brand: @brand, name: 'First')
    @second = ProductSeries.create!(brand: @brand, name: 'Second')
    @empty = ProductSeries.create!(brand: @brand, name: 'Empty')
  end

  def create_product(name, series: nil, added: Time.current, **attributes)
    travel_to(added) do
      Product.create!(name: "#{name} #{SecureRandom.hex(3)}", brand: @brand, product_series: series,
                      sub_categories: [sub_categories(:one)], **attributes)
    end
  end

  def by_series
    series = @brand.product_series.order(:name).to_a
    BrandLatestProducts.by_series(brand: @brand.reload, series:)
  end

  test 'products are ordered by release date, then undated ones by the date they were added' do
    old = create_product('Old', release_year: 1978)
    new_month = create_product('New Month', release_year: 2020, release_month: 5)
    new_year = create_product('New Year', release_year: 2020)
    undated_recent = create_product('Undated Recent', added: 2.days.from_now)
    undated_early = create_product('Undated Early', added: 1.day.from_now)

    preview = BrandLatestProducts.products(brand: @brand.reload)

    assert_equal [new_month.id, new_year.id, old.id, undated_recent.id, undated_early.id],
                 preview.items.map(&:product_id)
    assert_equal 5, preview.total_count
  end

  test 'products reads at most PRODUCTS_LIMIT rows and counts all' do
    (BrandLatestProducts::PRODUCTS_LIMIT + 1).times { |index| create_product("Many #{index}") }

    preview = BrandLatestProducts.products(brand: @brand.reload)

    assert_equal BrandLatestProducts::PRODUCTS_LIMIT, preview.items.size
    assert_equal BrandLatestProducts::PRODUCTS_LIMIT + 1, preview.total_count
  end

  test 'products leaves out variants' do
    product = create_product('With Variant')
    ProductVariant.create!(product:, name: 'Black', discontinued: false)

    preview = BrandLatestProducts.products(brand: @brand.reload)

    assert_equal ['Product'], preview.items.map(&:item_type)
    assert_equal 1, preview.total_count
  end

  test 'by_series lists the newest products of each series in the same order' do
    products = Array.new(5) { |index| create_product("Model #{index}", series: @first, release_year: 2000 + index) }
    other = create_product('Other', series: @second)

    previews = by_series

    assert_equal [@first, @second], previews.map(&:series)
    assert_equal products.last(4).reverse.map(&:id), previews.first.items.map(&:product_id)
    assert_equal 5, previews.first.total_count
    assert_equal [other.id], previews.second.items.map(&:product_id)
  end

  test 'by_series leaves out series without products' do
    create_product('Only', series: @first)

    assert_not_includes by_series.map(&:series), @empty
  end

  test 'by_series returns nothing for a brand without series products' do
    assert_empty by_series
  end
end
