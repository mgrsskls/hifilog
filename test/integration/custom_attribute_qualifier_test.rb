# frozen_string_literal: true

require 'test_helper'

# The qualifier as the contributor and the visitor meet it: the control in the product form and
# the reading on the product page.
class CustomAttributeQualifierTest < ActionDispatch::IntegrationTest
  setup do
    @definition = custom_attributes(:four)
    @definition.update!(units: %w[kg lb], qualifiers: %w[plus_minus_3_db plus_minus_6_db])
  end

  test 'the product form offers the conditions of the definition and a blank option' do
    sign_in users(:one)

    get new_product_path(brand_id: brands(:one).id)

    assert_response :success
    assert_select "select[name='product[custom_attributes][weight][qualifier]']" do
      assert_select 'option[value=""]', text: I18n.t('custom_attribute_qualifier.not_stated')
      assert_select "option[value='plus_minus_3_db']"
      assert_select "option[value='plus_minus_6_db']"
    end
  end

  test 'a definition with no conditions renders no control' do
    @definition.update!(qualifiers: [])
    sign_in users(:one)

    get new_product_path(brand_id: brands(:one).id)

    assert_response :success
    assert_select "select[name='product[custom_attributes][weight][qualifier]']", count: 0
  end

  test 'the product page shows the condition after the reading' do
    product = products(:without_custom_attributes)
    product.update!(custom_attributes: { 'weight' => { 'value' => 3, 'unit' => 'kg',
                                                       'qualifier' => 'plus_minus_3_db' } })

    get product_path(id: product.friendly_id)

    assert_response :success
    assert_select '.Data', text: /#{Regexp.escape(I18n.t('custom_attribute_qualifiers.plus_minus_3_db'))}/
  end

  # The shape the sensitivity migration leaves behind: one unit, and the drive reference as the
  # condition. The fixture stands in for the shape rather than for the attribute -- what is under
  # test is a single-unit measurement carrying a drive reference, not weight in decibels.
  test 'a sensitivity reading shows its drive reference and only one number' do
    @definition.update!(units: %w[db], qualifiers: %w[drive_1w_1m drive_283v_1m])
    product = products(:without_custom_attributes)
    product.update!(custom_attributes: { 'weight' => { 'value' => 88, 'unit' => 'db',
                                                       'qualifier' => 'drive_283v_1m' } })

    get product_path(id: product.friendly_id)

    assert_response :success
    assert_select '.Data', text: /88/
    assert_select '.Data', text: /#{Regexp.escape(I18n.t('custom_attribute_qualifiers.drive_283v_1m'))}/
  end

  test 'the product page shows no parentheses when no condition is recorded' do
    product = products(:without_custom_attributes)
    product.update!(custom_attributes: { 'weight' => { 'value' => 3, 'unit' => 'kg' } })

    get product_path(id: product.friendly_id)

    assert_response :success
    assert_select '.Data', text: /#{Regexp.escape(I18n.t('custom_attribute_qualifiers.plus_minus_3_db'))}/,
                           count: 0
  end
end
