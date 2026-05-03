# frozen_string_literal: true

require 'test_helper'

class CacheServiceTest < ActiveSupport::TestCase
  test 'menu aggregates cluster categories similarly to seeded columns' do
    grouped = CacheService.menu_categories

    assert_predicate grouped.keys, :present?
    flattened = grouped.values.flatten

    assert_operator flattened.count, :>=, Category.count
    assert(flattened.any?(Category))
  end

  test 'cached counters align with authoritative SQL counts' do
    catalog_total = Product.count + ProductVariant.count

    assert_equal catalog_total, CacheService.products_count
    assert_equal Brand.count, CacheService.brands_count
    assert_equal SubCategory.count, CacheService.categories_count
  end

  test 'recent activity feeds truncate to deterministic windows' do
    products = CacheService.newest_products
    brands = CacheService.newest_brands

    assert_operator products.size, :<=, 10
    assert_operator brands.size, :<=, 10
    assert(products.all? { |record| record.is_a?(Product) || record.is_a?(ProductVariant) })
    assert(brands.all?(Brand))
  end
end
