# frozen_string_literal: true

require 'test_helper'

# The admin form is the only place a definition's conditions are set, so the round trip through it
# is asserted rather than assumed: permitted parameters, the save, and the show page that the
# update redirects to.
class AdminCustomAttributeQualifiersTest < ActionDispatch::IntegrationTest
  setup do
    sign_in admin_users(:admin_user)
    @definition = custom_attributes(:four)
  end

  test 'the form offers every valid qualifier' do
    get edit_admin_custom_attribute_path(@definition)

    assert_response :success
    CustomAttribute::VALID_QUALIFIERS.each do |qualifier|
      assert_select "input[name='custom_attribute[qualifiers][]'][value='#{qualifier}']"
    end
  end

  test 'an update saves the ticked qualifiers' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: {
        label: @definition.label,
        highlighted: @definition.highlighted ? '1' : '0',
        input_type: 'number',
        qualifiers: ['', 'plus_minus_3_db', 'plus_minus_6_db']
      }
    }

    assert_equal %w[plus_minus_3_db plus_minus_6_db], @definition.reload.qualifiers
  end

  test 'an update with no qualifiers clears them' do
    @definition.update!(qualifiers: %w[plus_minus_3_db])

    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: {
        label: @definition.label,
        highlighted: @definition.highlighted ? '1' : '0',
        input_type: 'number',
        qualifiers: ['']
      }
    }

    assert_empty @definition.reload.qualifiers
  end

  test 'the show page names the saved qualifiers' do
    @definition.update!(input_type: 'number', qualifiers: %w[plus_minus_3_db])

    get admin_custom_attribute_path(@definition)

    assert_response :success
    assert_select 'body', text: /#{Regexp.escape(I18n.t('custom_attribute_qualifiers.plus_minus_3_db'))}/
  end

  test 'switching to an input type without measurements clears the qualifiers' do
    @definition.update!(input_type: 'number', qualifiers: %w[plus_minus_3_db])

    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: {
        label: @definition.label,
        highlighted: @definition.highlighted ? '1' : '0',
        input_type: 'boolean'
      }
    }

    assert_empty @definition.reload.qualifiers
  end
end
