# frozen_string_literal: true

require 'test_helper'

class BrandFilterServiceTest < ActiveSupport::TestCase
  def setup
    @category = categories(:one)
    @sub_category = sub_categories(:one)
    @brand = brands(:one)
    @discontinued_brand = brands(:two)
  end

  test 'filter by category returns correct brands' do
    result = BrandFilterService.new(filters: {}, category: @category).filter
    assert_equal [brands(:one)], result.brands.to_a
  end

  test 'filter by sub_category returns correct brands' do
    result = BrandFilterService.new(filters: {}, category: nil, sub_category: @sub_category).filter
    assert_equal [brands(:one)], result.brands.to_a
  end

  test 'filter by status returns only discontinued brands' do
    result = BrandFilterService.new(filters: { status: 'discontinued' }).filter
    assert_equal [brands(:three)], result.brands.to_a
    assert result.brands.all?(&:discontinued)
  end

  test 'filter by query returns only matching brands' do
    brand = brands(:one)
    result = BrandFilterService.new(filters: { query: brand.name }).filter
    assert_equal [brand], result.brands.to_a
  end

  test 'filter by country returns only brands from that country' do
    result = BrandFilterService.new(filters: { country: 'US' }).filter
    assert_equal [brands(:one), brands(:three)].sort_by(&:id), result.brands.to_a.sort_by(&:id)
    assert(result.brands.all? { |brand| brand.country_code == 'US' })
  end

  test 'filter by diy_kit returns only brands with diy kit products' do
    result = BrandFilterService.new(product_filters: { diy_kit: '1' }).filter
    assert_equal [brands(:two)], result.brands.to_a
  end

  test 'filter by custom attributes returns correct brands' do
    custom_attribute = custom_attributes(:one)
    result = BrandFilterService.new(product_filters: { custom: { custom_attribute.label => ['1'] } }).filter
    assert result.brands.any?
    assert_equal [brands(:one)], result.brands.to_a
    assert(result.brands.all? do |brand|
      brand.products.exists?(['custom_attributes ->> ? IN (?)', custom_attribute.label, ['1']])
    end)
  end

  test 'sorting by name_desc returns brands in reverse alphabetical order' do
    result = BrandFilterService.new(filters: { sort: 'name_desc' }).filter
    names = result.brands.map(&:name).map(&:downcase)
    assert_equal names.sort.reverse, names
  end

  test 'sorting by products_count returns brands in correct order' do
    result = BrandFilterService.new(filters: { sort: 'products_desc' }).filter
    counts = result.brands.map(&:products_count)

    assert_equal counts.sort.reverse, counts
  end

  test 'sorting by products with category uses matching product counts not totals' do
    category = categories(:two)
    brand_with_matching = brands(:two)
    brand_without_matching = brands(:three)

    # brand_without_matching is linked to the category via brands_sub_categories but its product
    # lives in another category — total products_count would incorrectly rank it first.
    brand_without_matching.update!(products_count: 100)
    brand_with_matching.update!(products_count: 1)

    result = BrandFilterService.new(
      filters: { sort: 'products_desc' },
      category:
    ).filter.brands.to_a

    assert_includes result, brand_with_matching
    assert_includes result, brand_without_matching
    assert_operator result.index(brand_with_matching), :<, result.index(brand_without_matching)
  end

  test 'sorting by products with product filters uses matching product counts not totals' do
    brand_with_one_match = brands(:two)
    brand_with_two_matches = brands(:one)

    Product.create!(
      name: 'Another DIY',
      brand: brand_with_two_matches,
      slug: 'another-diy',
      diy_kit: true,
      sub_category_ids: [sub_categories(:one).id]
    )
    Product.create!(
      name: 'Third DIY',
      brand: brand_with_two_matches,
      slug: 'third-diy',
      diy_kit: true,
      sub_category_ids: [sub_categories(:one).id]
    )

    # Totals would rank brand_with_one_match first if we used products_count.
    brand_with_one_match.update!(products_count: 100)
    brand_with_two_matches.update!(products_count: 2)

    result = BrandFilterService.new(
      filters: { sort: 'products_desc' },
      product_filters: { diy_kit: '1' }
    ).filter.brands.to_a

    assert_includes result, brand_with_two_matches
    assert_includes result, brand_with_one_match
    assert_operator result.index(brand_with_two_matches), :<, result.index(brand_with_one_match)
  end

  test 'return all brands without any params' do
    result = BrandFilterService.new(filters: {}).filter
    assert_equal Brand.all.to_a.sort_by(&:id), result.brands.to_a.sort_by(&:id)
  end

  test 'combines multiple filters correctly' do
    result = BrandFilterService.new(filters: {
                                      status: 'discontinued',
                                      country: 'US',
                                      letter: 'b'
                                    }).filter
    assert_equal [brands(:three)], result.brands.to_a
    assert(result.brands.all? do |brand|
      brand.discontinued &&
        brand.country_code == 'US' &&
        brand.name.downcase.starts_with?('b')
    end)
  end

  test 'sorting exposes ascending product volume ordering' do
    result = BrandFilterService.new(filters: { sort: 'products_asc' }).filter
    counts = result.brands.pluck(:products_count)

    assert_equal counts.sort, counts
  end

  test 'ordering supports created and metadata sort keys without errors' do
    %w[added_asc added_desc updated_asc updated_desc].each do |sort|
      result = BrandFilterService.new(filters: { sort: }).filter

      assert_operator result.brands.count, :positive?
      assert_nothing_raised { result.brands.load }
    end
  end
end
