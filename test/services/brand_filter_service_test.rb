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

  test 'product filters are scoped to the selected sub_category' do
    brand = brands(:two)
    matching_sub_category = sub_categories(:two)
    other_sub_category = sub_categories(:one)

    # Brand is linked to another sub_category, but its only diy_kit product lives elsewhere.
    brand.sub_categories << other_sub_category unless brand.sub_category_ids.include?(other_sub_category.id)

    result_outside = BrandFilterService.new(
      product_filters: { diy_kit: '1' },
      sub_category: other_sub_category
    ).filter

    result_inside = BrandFilterService.new(
      product_filters: { diy_kit: '1' },
      sub_category: matching_sub_category
    ).filter

    assert_not_includes result_outside.brands.to_a, brand
    assert_includes result_inside.brands.to_a, brand
  end

  test 'product filters are scoped to the selected category' do
    brand = brands(:two)
    matching_category = categories(:two)
    other_category = categories(:one)
    other_sub_category = sub_categories(:one)

    brand.sub_categories << other_sub_category unless brand.sub_category_ids.include?(other_sub_category.id)

    result_outside = BrandFilterService.new(
      product_filters: { diy_kit: '1' },
      category: other_category
    ).filter

    result_inside = BrandFilterService.new(
      product_filters: { diy_kit: '1' },
      category: matching_category
    ).filter

    assert_not_includes result_outside.brands.to_a, brand
    assert_includes result_inside.brands.to_a, brand
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

  test 'ordering supports created and metadata sort keys without errors' do
    %w[added_asc added_desc updated_asc updated_desc].each do |sort|
      result = BrandFilterService.new(filters: { sort: }).filter

      assert_operator result.brands.count, :positive?
      assert_nothing_raised { result.brands.load }
    end
  end

  test 'relevance tier outranks the hand-picked sort when a query is present' do
    Brand.create!(name: 'Audio')
    Brand.create!(name: 'Audio Note')
    Brand.create!(name: 'Zeta Audio')

    result = BrandFilterService.new(filters: { query: 'Audio', sort: 'name_desc' }).filter

    # name_desc on its own would start at "Zeta Audio". The relevance tier pulls
    # the exact match up first, then the prefix match, then the substring ones.
    assert_equal ['Audio', 'Audio Note', 'Zeta Audio', 'Feliks Audio'], result.brands.map(&:name)
  end

  test 'hand-picked sort still orders brands inside a relevance tier' do
    Brand.create!(name: 'Audio Alpha')
    Brand.create!(name: 'Audio Beta')

    ascending = BrandFilterService.new(filters: { query: 'Audio', sort: 'name_asc' }).filter
    descending = BrandFilterService.new(filters: { query: 'Audio', sort: 'name_desc' }).filter

    prefix_tier = ->(result) { result.brands.map(&:name).select { |name| name.start_with?('Audio ') } }

    assert_equal ['Audio Alpha', 'Audio Beta'], prefix_tier.call(ascending)
    assert_equal ['Audio Beta', 'Audio Alpha'], prefix_tier.call(descending)
  end

  test 'relevance ordering ignores accents' do
    Brand.create!(name: 'Ölufsen')
    Brand.create!(name: 'Zeta Olufsen')

    result = BrandFilterService.new(filters: { query: 'Olufsen', sort: 'name_desc' }).filter

    assert_equal ['Ölufsen', 'Zeta Olufsen'], result.brands.map(&:name)
  end

  test 'query with LIKE wildcards is matched literally' do
    Brand.create!(name: '100% Audio')

    result = BrandFilterService.new(filters: { query: '100% Audio' }).filter

    assert_includes result.brands.map(&:name), '100% Audio'
  end

  test 'relevance ordering leaves the plain sort untouched without a query' do
    result = BrandFilterService.new(filters: { sort: 'name_asc' }).filter
    names = result.brands.map(&:name).map(&:downcase)

    assert_equal names.sort, names
  end
end
