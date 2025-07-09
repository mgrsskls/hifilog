require 'test_helper'

class BrandFilterServiceTest < ActiveSupport::TestCase
  def setup
    @category = categories(:one)
    @sub_category = sub_categories(:one)
    @brand = brands(:one)
    @discontinued_brand = brands(:two)
  end

  test 'filter by category returns correct brands' do
    result = BrandFilterService.new({}, @category).filter
    assert_equal [brands(:one)], result.brands.to_a
  end

  test 'filter by sub_category returns correct brands' do
    result = BrandFilterService.new({}, nil, @sub_category).filter
    assert_equal [brands(:one)], result.brands.to_a
  end

  test 'filter by status returns only discontinued brands' do
    result = BrandFilterService.new({ status: 'discontinued' }).filter
    assert_equal [brands(:three)], result.brands.to_a
    assert result.brands.all?(&:discontinued)
  end

  test 'filter by query returns only matching brands' do
    brand = brands(:one)
    result = BrandFilterService.new({ query: brand.name }).filter
    assert_equal [brand], result.brands.to_a
  end

  test 'filter by country returns only brands from that country' do
    result = BrandFilterService.new({ country: 'US' }).filter
    assert_equal [brands(:one), brands(:three)].sort_by(&:id), result.brands.to_a.sort_by(&:id)
    assert(result.brands.all? { |brand| brand.country_code == 'US' })
  end

  test 'filter by diy_kit returns only brands with diy kit products' do
    result = BrandFilterService.new({ diy_kit: '1' }).filter
    assert_equal [brands(:two)], result.brands.to_a
  end

  test 'filter by custom attributes returns correct brands' do
    custom_attribute = custom_attributes(:one)
    result = BrandFilterService.new({ attr: { custom_attribute.id.to_s => ['1'] } }).filter
    assert result.brands.any?
    assert_equal [brands(:one)], result.brands.to_a
    assert(result.brands.all? do |brand|
      brand.products.exists?(['custom_attributes ->> ? IN (?)', custom_attribute.id.to_s, ['1']])
    end)
  end

  test 'sorting by name_desc returns brands in reverse alphabetical order' do
    result = BrandFilterService.new({ sort: 'name_desc' }).filter
    names = result.brands.map(&:name).map(&:downcase)
    assert_equal names.sort.reverse, names
  end

  test 'sorting by products_count returns brands in correct order' do
    result = BrandFilterService.new({ sort: 'products_desc' }).filter
    counts = result.brands.map(&:products_count)
    assert_equal counts.sort.reverse, counts
  end

  test 'return all brands without any params' do
    result = BrandFilterService.new({}).filter
    assert_equal Brand.all.to_a.sort_by(&:id), result.brands.to_a.sort_by(&:id)
  end

  test 'combines multiple filters correctly' do
    result = BrandFilterService.new({
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
end
