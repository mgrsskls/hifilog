# frozen_string_literal: true

require 'test_helper'

# The qualifier as the contributor and the visitor meet it: the control in the product form, the
# reading on the product page, and the one thing that keeps a change of the condition from
# rewriting the number.
class CustomAttributeQualifierTest < ActionDispatch::IntegrationTest
  ENTITY_FORM_JS = Rails.root.join('app/assets/javascripts/entity_form.js')

  setup do
    @definition = custom_attributes(:four)
    @definition.update!(units: %w[kg lb], qualifiers: %w[plus_minus_3_db plus_minus_6_db])
  end

  # entity_form.js converts the number that is shown when a unit changes, because two units are
  # two spellings of one value. A condition is not: a figure measured at ±6 dB is a different
  # measurement, not the same one restated, so the number must stay as it was typed.
  #
  # Nothing in the JavaScript opts the qualifier out. The whole protection is the end of one
  # selector, which is why it is asserted here: widen it to `[name*="unit"]`, or rename the
  # control, and the converter would start rewriting figures with no error anywhere.
  test 'the unit converter is bound only to controls whose name ends in unit' do
    source = ENTITY_FORM_JS.read

    assert_includes source, 'input[type="radio"][name$="[unit]"]'
    assert_no_match(/querySelectorAll\(\s*['"`][^'"`]*\[qualifier\]/, source)
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
