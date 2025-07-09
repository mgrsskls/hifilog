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
    brand = brands(:three)
    discontinued_product = products(:discontinued)

    result = ProductFilterService.new({ discontinued: true }, [brand]).filter

    assert_equal [discontinued_product.id], result.products.pluck(:product_id)
    assert(result.products.all? { |pi| pi.discontinued == true })
  end

  test 'filter by query returns only matching products' do
    product = products(:one)
    result = ProductFilterService.new({ query: product.name }, [@brand]).filter
    assert_equal [product.id], result.products.pluck(:id)
  end
end
