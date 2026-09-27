# frozen_string_literal: true

require 'test_helper'

# A sub category that offers other units for an attribute than the definition: cartridges weigh
# grams, loudspeakers kilograms. See docs/custom-attributes.md, "Units per sub category".
class CustomAttributeSubCategoryUnitsTest < ActionDispatch::IntegrationTest
  setup do
    @weight = custom_attributes(:four)
    @weight.update!(units: %w[lb kg g])
    @cartridges = SubCategory.create!(name: 'Cartridges', category: categories(:one))
    @weight.sub_categories << @cartridges
    links = CustomAttributeSubCategory.where(custom_attribute: @weight)
    links.where.not(sub_category: @cartridges).find_each { |link| link.update!(units: %w[lb kg]) }
    links.find_by!(sub_category: @cartridges).update!(units: %w[g])
    @product = products(:without_custom_attributes)
  end

  test 'the product form renders the weight once for each group of units' do
    sign_in users(:one)

    get edit_product_path(id: @product.friendly_id)

    assert_response :success
    assert_select "[data-unit-variant='weight']", count: 2 do |variants|
      ids = variants.map { |variant| JSON.parse(variant['data-sub-category-ids']).sort }
      assert_equal [[sub_categories(:one).id, sub_categories(:two).id].sort, [@cartridges.id]], ids
    end
    # The gram group posts its unit, because it differs from the units of the definition.
    assert_select "input[type=hidden][name='product[custom_attributes][weight][unit]'][value=g]"
    assert_select "input[id='product[custom_attributes][weight-g]']"
  end

  # entity_form.js keeps this block enabled when no ticked sub category applies, so the figure is
  # not deleted.
  test 'the product form marks the block that offers the stored unit' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 6.5, 'unit' => 'g' } })
    sign_in users(:one)

    get edit_product_path(id: @product.friendly_id)

    assert_select '[data-unit-variant-keeps-value]', count: 1 do |blocks|
      assert_equal [@cartridges.id], JSON.parse(blocks.first['data-sub-category-ids'])
    end
  end

  test 'the product form shows a kilogram figure in grams for the gram group' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 0.0065, 'unit' => 'kg' } })
    sign_in users(:one)

    get edit_product_path(id: @product.friendly_id)

    assert_select "input[id='product[custom_attributes][weight-g]'][value='6.5']"
  end

  test 'saving the product form keeps a figure in grams' do
    sign_in users(:one)

    patch product_url(id: @product.id), params: {
      product: {
        name: @product.name,
        discontinued: @product.discontinued,
        sub_category_ids: [@cartridges.id],
        custom_attributes: { 'weight' => { 'value' => '6.5', 'unit' => 'g' } }
      }
    }

    assert_response :redirect
    assert_equal({ 'value' => 6.5, 'unit' => 'g' }, @product.reload.custom_attributes['weight'])
  end

  # The definition offers kg and lb, so a figure in kilograms still shows its figure in pounds.
  test 'the product page shows a kilogram figure with its pound figure' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 15, 'unit' => 'kg' } })

    get product_path(id: @product.friendly_id)

    assert_select '.Data dd', text: %r{15 kg\s*/\s*33 lb}
  end

  test 'the product page shows a figure in grams without a converted figure' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 6.5, 'unit' => 'g' } })

    get product_path(id: @product.friendly_id)

    assert_response :success
    assert_select '.Data dd', text: /\A\s*6.5 g\s*\z/
  end
end
