require 'test_helper'

class ProductFilterServiceTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    @category = categories(:one)
    @sub_category = sub_categories(:one)
    @product = products(:one)
  end

  test 'filter by category returns correct products' do
    result = ProductFilterService.new({}, [@brand], categories(:two)).filter
    assert_equal @brand.products
                       .joins(:sub_categories)
                       .where(sub_categories: { category_id: categories(:two).id })
                       .to_a,
                 result.products.to_a
  end

  test 'filter by sub_category returns correct products' do
    result = ProductFilterService.new({}, [@brand], nil, sub_categories(:two)).filter
    assert_equal @brand.products.joins(:sub_categories).where(sub_categories: { id: sub_categories(:two).id }).to_a,
                 result.products.to_a
  end

  test 'filter by status returns only discontinued products' do
    result = ProductFilterService.new({ status: 'discontinued' }, [brands(:three)]).filter
    assert_equal [products(:discontinued)], result.products.to_a
    assert result.products.all?(&:discontinued)
  end

  test 'filter by letter returns only products starting with that letter' do
    result = ProductFilterService.new({ letter: 'E' }, [@brand]).filter
    assert_equal [products(:one)], result.products.to_a
    assert(result.products.all? { |p| p.name.downcase.starts_with?('e') })
  end

  test 'filter by query returns only matching products' do
    product = products(:one)
    result = ProductFilterService.new({ query: product.name }, [@brand]).filter
    assert_equal [product], result.products.to_a
  end
end
