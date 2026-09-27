# frozen_string_literal: true

require 'test_helper'

# See docs/custom-attributes.md, "Units per sub category".
class SubCategoryUnitConversionTest < ActiveSupport::TestCase
  setup do
    @weight = custom_attributes(:four)
    @weight.update!(units: %w[lb kg g])
    link(sub_categories(:one)).update!(units: %w[g])
    link(sub_categories(:two)).update!(units: %w[lb kg])
    @product = products(:without_custom_attributes)
  end

  test 'a dry run lists the entry and writes nothing' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 0.35, 'unit' => 'kg' } })

    results = SubCategoryUnitConversion.new.call

    assert_equal [{ 'value' => 350.0, 'unit' => 'g' }], results.map(&:after)
    assert_equal 'kg', @product.reload.custom_attributes.dig('weight', 'unit')
  end

  test 'apply converts the entry into the unit of the sub category, and a second run changes nothing' do
    @product.update!(custom_attributes: {
                       'weight' => { 'value' => 0.35, 'unit' => 'kg', 'second' => { 'value' => 0.77, 'unit' => 'lb' } }
                     })

    SubCategoryUnitConversion.new.call(apply: true)

    assert_equal({ 'value' => 350.0, 'unit' => 'g' }, @product.reload.custom_attributes['weight'])
    assert_empty SubCategoryUnitConversion.new.call
  end

  test 'an entry in a unit of the sub category is left alone' do
    link(sub_categories(:one)).update!(units: %w[lb kg])
    @product.update!(custom_attributes: { 'weight' => { 'value' => 15, 'unit' => 'kg' } })

    assert_empty SubCategoryUnitConversion.new.call
  end

  test 'an entry without a unit reads in the first unit of the definition' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 1 } })

    # 1 lb is 453.59 g, rounded to two significant figures.
    assert_equal [{ 'value' => 450.0, 'unit' => 'g' }], SubCategoryUnitConversion.new.call.map(&:after)
  end

  test 'a product in two sub categories uses the first one in menu order' do
    categories(:one).update!(order: 2)
    categories(:two).update!(order: 1)
    @product.update!(sub_categories: [sub_categories(:one), sub_categories(:two)],
                     custom_attributes: { 'weight' => { 'value' => 0.35, 'unit' => 'kg' } })

    # Over-Ear Headphones (kg and lb) comes before Headphone Amplifiers (g).
    assert_empty SubCategoryUnitConversion.new.call
  end

  test 'labels limits the conversion to these attributes' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 0.35, 'unit' => 'kg' } })

    assert_empty SubCategoryUnitConversion.new(labels: %w[dimensions]).call
    assert_equal 1, SubCategoryUnitConversion.new(labels: %w[weight]).call.size
  end

  private

  def link(sub_category)
    CustomAttributeSubCategory.find_by!(custom_attribute: @weight, sub_category:)
  end
end
