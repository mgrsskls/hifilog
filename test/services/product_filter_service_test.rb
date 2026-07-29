# frozen_string_literal: true

require 'test_helper'

class ProductFilterServiceTest < ActiveSupport::TestCase
  def setup
    @brand = brands(:one)
    @category = categories(:one)
    @sub_category = sub_categories(:one)
    @product = products(:one)
  end

  test 'filter by category returns correct products' do
    result = ProductFilterService.new(filters: {}, brands: [@brand], category: categories(:two)).filter
    assert_equal @brand.products
                       .joins(:sub_categories)
                       .where(sub_categories: { category_id: categories(:two).id })
                       .to_a,
                 result.products.to_a
  end

  test 'filter by sub_category returns correct products' do
    result = ProductFilterService.new(filters: {}, brands: [@brand], sub_category: sub_categories(:two)).filter
    assert_equal @brand.products.joins(:sub_categories).where(sub_categories: { id: sub_categories(:two).id }).to_a,
                 result.products.to_a
  end

  test 'filter by status discontinued returns only discontinued product items' do
    brand = brands(:three)
    discontinued_product = products(:discontinued)

    result = ProductFilterService.new(filters: { status: 'discontinued' }, brands: [brand]).filter

    assert_equal [discontinued_product.id], result.products.pluck(:product_id)
    assert(result.products.all? { |pi| pi.discontinued == true })
  end

  test 'filter by status continued excludes discontinued product items' do
    brand = brands(:three)

    result = ProductFilterService.new(filters: { status: 'continued' }, brands: [brand]).filter

    assert_empty result.products
  end

  test 'filter by query returns only matching products' do
    product = products(:one)
    result = ProductFilterService.new(filters: { query: product.name }, brands: [@brand]).filter
    assert_equal [product.id], result.products.pluck(:product_id)
  end

  test 'filter by country limits to brand country code' do
    result = ProductFilterService.new(filters: { country: ' de ' }, brands: [brands(:two)]).filter

    assert(result.products.all? { |pi| pi.brand.country_code == 'DE' })
    assert_includes result.products.pluck(:product_id), products(:two).id
  end

  test 'filter by diy_kit' do
    result = ProductFilterService.new(filters: { diy_kit: '1' }, brands: [brands(:two)]).filter

    assert_equal [products(:diy_kit).id], result.products.pluck(:product_id)
  end

  test 'filter by custom option attribute' do
    product = products(:with_custom_attributes)

    result = ProductFilterService.new(
      filters: { custom: { 'amplifier_channel_type' => '1' } },
      brands: [@brand]
    ).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter by custom boolean attribute' do
    product = products(:with_custom_attributes)

    result = ProductFilterService.new(
      filters: { custom: { 'boolean' => '1' } },
      brands: [@brand]
    ).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter by custom options array attribute' do
    product = products(:with_custom_attributes)

    result = ProductFilterService.new(
      filters: { custom: { 'multiple_options' => %w[1 2] } },
      brands: [@brand]
    ).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter by numeric custom attribute range' do
    product = products(:without_custom_attributes)
    product.update!(
      custom_attributes: {
        'number' => { 'value' => '5.0', 'unit' => 'cm' }
      }
    )

    custom = {
      'number' => ActiveSupport::HashWithIndifferentAccess.new(
        min: '1',
        max: '10',
        unit: 'cm'
      )
    }

    result = ProductFilterService.new(filters: { custom: }, brands: [@brand]).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter applies inch to centimetre conversion for numeric custom attribute' do
    product = products(:without_custom_attributes)
    product.update!(
      custom_attributes: {
        'number' => { 'value' => '5.08', 'unit' => 'cm' }
      }
    )

    custom = {
      'number' => ActiveSupport::HashWithIndifferentAccess.new(
        min: '2',
        max: '2',
        unit: 'in'
      )
    }

    result = ProductFilterService.new(filters: { custom: }, brands: [@brand]).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter applies brand_filters country to product results' do
    result = ProductFilterService.new(
      filters: {},
      brands: [brands(:one), brands(:two)],
      brand_filters: { country: 'DE' }
    ).filter

    assert(result.products.all? { |pi| pi.brand.country_code == 'DE' })
  end

  test 'sort keys apply without SQL error' do
    %w[
      name_desc
      release_date_asc
      release_date_desc
      added_asc
      added_desc
      updated_asc
      updated_desc
    ].each do |sort|
      result = ProductFilterService.new(filters: { sort: }, brands: []).filter
      assert_kind_of ActiveRecord::Relation, result.products
      result.products.load
    end
  end

  test 'default sort path when sort blank' do
    result = ProductFilterService.new(filters: {}, brands: [@brand]).filter
    assert_kind_of ActiveRecord::Relation, result.products
    result.products.load
  end

  test 'uses all product items when brands array empty' do
    result = ProductFilterService.new(filters: {}, brands: []).filter
    assert_equal ProductItem.count, result.products.count
  end

  test 'filter by multi input numeric attribute respects each dimension constraint' do
    product = products(:with_custom_attributes)
    ca = custom_attributes(:six)
    label = ca.label
    attrs = JSON.parse(product.custom_attributes.to_json).merge(
      label => {
        'value' => { 'w' => '25.4', 'h' => '20', 'l' => '10' },
        'unit' => 'cm'
      }
    )

    product.update!(custom_attributes: attrs)

    custom = {
      label => ActiveSupport::HashWithIndifferentAccess.new(
        unit: 'in',
        w: { min: '9', max: '11' },
        h: { min: '5', max: '30' },
        l: { min: '1', max: '12' }
      )
    }

    result = ProductFilterService.new(filters: { custom: }, brands: [@brand]).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'filter converts pound filters to stored kilogram values' do
    product = products(:without_custom_attributes)
    product.update!(
      custom_attributes: {
        'number' => { 'value' => '0.907184', 'unit' => 'kg' }
      }
    )

    custom = {
      'number' => ActiveSupport::HashWithIndifferentAccess.new(
        min: '2',
        max: '2',
        unit: 'lb'
      )
    }

    result = ProductFilterService.new(filters: { custom: }, brands: [@brand]).filter

    assert_includes result.products.pluck(:product_id), product.id
  end

  test 'paginated ordered brand relation scopes products to the same page of brands' do
    ordered_page = BrandFilterService.new(filters: { sort: 'name_asc' }).filter.brands.page(1)
    page_brand_ids = ordered_page.map(&:id)

    result = ProductFilterService.new(filters: {}, brands: ordered_page).filter
    counted_brand_ids = result.products.except(:order).distinct.pluck(:brand_id)

    assert_equal page_brand_ids.sort, counted_brand_ids.sort
  end

  test 'counts_by_brand with sub_category matches product_items grouping and includes variants' do
    brand = brands(:two)
    sub_category = sub_categories(:two)
    expected = ProductFilterService.new(
      filters: {},
      brands: [brand],
      sub_category:
    ).filter.products.except(:order).group(:brand_id).count

    counts = ProductFilterService.new(
      filters: {},
      brands: [brand],
      sub_category:
    ).counts_by_brand

    assert_equal expected, counts
    assert_operator counts[brand.id], :>, brand.products.joins(:sub_categories)
                                               .where(sub_categories: { id: sub_category.id }).count
  end

  test 'counts_by_brand with category matches product_items grouping' do
    brand = brands(:two)
    category = categories(:two)
    expected = ProductFilterService.new(
      filters: {},
      brands: [brand],
      category:
    ).filter.products.except(:order).group(:brand_id).count

    counts = ProductFilterService.new(
      filters: {},
      brands: [brand],
      category:
    ).counts_by_brand

    assert_equal expected, counts
  end

  test 'counts_by_brand with product filters still matches product_items grouping' do
    expected = ProductFilterService.new(
      filters: { diy_kit: '1' },
      brands: [brands(:two)]
    ).filter.products.except(:order).group(:brand_id).count

    counts = ProductFilterService.new(
      filters: { diy_kit: '1' },
      brands: [brands(:two)]
    ).counts_by_brand

    assert_equal expected, counts
  end

  test 'counts_by_brand accepts loaded brand ids without re-querying a relation' do
    brand = brands(:one)
    sub_category = sub_categories(:one)

    counts = ProductFilterService.new(
      filters: {},
      brands: [brand.id],
      sub_category:
    ).counts_by_brand

    assert_equal brand.id, counts.keys.sole
    assert_operator counts[brand.id], :positive?
  end

  test 'total_count with sub_category matches product_items count and includes variants' do
    brand = brands(:two)
    sub_category = sub_categories(:two)
    expected = ProductFilterService.new(
      filters: {},
      brands: [brand],
      sub_category:
    ).filter.products.except(:order).count

    total = ProductFilterService.new(
      filters: {},
      brands: [brand],
      sub_category:
    ).total_count

    assert_equal expected, total
    assert_operator total, :>, brand.products.joins(:sub_categories)
                                    .where(sub_categories: { id: sub_category.id }).count
  end

  test 'total_count with category matches product_items count' do
    brand = brands(:two)
    category = categories(:two)
    expected = ProductFilterService.new(
      filters: {},
      brands: [brand],
      category:
    ).filter.products.except(:order).count

    total = ProductFilterService.new(
      filters: {},
      brands: [brand],
      category:
    ).total_count

    assert_equal expected, total
  end

  test 'total_count with product filters still matches product_items count' do
    expected = ProductFilterService.new(
      filters: { diy_kit: '1' },
      brands: [brands(:two)]
    ).filter.products.except(:order).count

    total = ProductFilterService.new(
      filters: { diy_kit: '1' },
      brands: [brands(:two)]
    ).total_count

    assert_equal expected, total
  end

  test 'total_count falls back to the view count when a search query is present' do
    product = products(:one)

    expected = ProductFilterService.new(
      filters: { query: product.name },
      brands: [@brand]
    ).filter.products.except(:order).count

    total = ProductFilterService.new(
      filters: { query: product.name },
      brands: [@brand]
    ).total_count

    assert_equal expected, total
  end

  test 'total_count accepts loaded brand ids without re-querying a relation' do
    brand = brands(:one)
    sub_category = sub_categories(:one)

    total = ProductFilterService.new(
      filters: {},
      brands: [brand.id],
      sub_category:
    ).total_count

    assert_operator total, :positive?
  end
end
