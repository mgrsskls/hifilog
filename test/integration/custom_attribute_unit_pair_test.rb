# frozen_string_literal: true

require 'test_helper'

# Two figures of one quantity as the contributor and the visitor meet them: one form row for each
# unit, and both figures on the product page. See docs/custom-attributes.md, "Two units".
class CustomAttributeUnitPairTest < ActionDispatch::IntegrationTest
  setup do
    custom_attributes(:four).update!(units: %w[lb kg])
    @product = products(:without_custom_attributes)
  end

  test 'the product form has one row for each unit, metric first, without unit radios' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 33, 'unit' => 'lb' } })
    sign_in users(:one)

    get edit_product_path(id: @product.friendly_id)

    assert_response :success
    assert_select '[data-unit-pair-row]' do |rows|
      # Dimensions (cm, in) and weight (defined as lb, kg): metric first in both.
      assert_equal %w[cm in kg lb], rows.pluck('data-unit-pair-row')
    end
    assert_select "input[type=hidden][name='product[custom_attributes][weight][unit]'][value=kg]"
    assert_select "input[type=hidden][name='product[custom_attributes][weight][second][unit]'][value=lb]"
    # The stored imperial figure lands in the imperial row.
    assert_select "input[name='product[custom_attributes][weight][second][value]'][value='33']"
    assert_select "input[type=radio][name='product[custom_attributes][weight][unit]']", count: 0
  end

  # Otherwise both rows are empty, and saving the form deletes the figure.
  test 'the product form shows a figure without a unit in the row of the first unit' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 25 } })
    sign_in users(:one)

    get edit_product_path(id: @product.friendly_id)

    assert_response :success
    assert_select "input[name='product[custom_attributes][weight][second][value]'][value='25']"
  end

  test 'the product page shows both stated figures' do
    @product.update!(
      custom_attributes: { 'weight' => { 'value' => 15, 'unit' => 'kg',
                                         'second' => { 'value' => 34, 'unit' => 'lb' } } }
    )

    get product_path(id: @product.friendly_id)

    assert_response :success
    assert_select '.Data dd', text: %r{15 kg\s*/\s*34 lb}
  end

  test 'the product page rounds a converted figure to the stated one' do
    @product.update!(custom_attributes: { 'weight' => { 'value' => 15, 'unit' => 'kg' } })

    get product_path(id: @product.friendly_id)

    assert_response :success
    assert_select '.Data dd', text: %r{15 kg\s*/\s*33 lb}
  end
end
