# frozen_string_literal: true

require 'test_helper'

# The admin form is the only place where the display group and the display position are set.
# These tests check the round trip: the form fields, the permitted parameters and the save.
class AdminCustomAttributeDisplayOrderTest < ActionDispatch::IntegrationTest
  setup do
    sign_in admin_users(:admin_user)
    @definition = custom_attributes(:four)
  end

  test 'the form offers every display group and a position field' do
    get edit_admin_custom_attribute_path(@definition)

    assert_response :success
    CustomAttribute::DISPLAY_GROUPS.each do |group|
      assert_select "select[name='custom_attribute[display_group]'] option[value='#{group}']"
    end
    assert_select "input[name='custom_attribute[display_position]']"
  end

  test 'an update saves the display group and the display position' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: {
        label: @definition.label,
        highlighted: @definition.highlighted ? '1' : '0',
        display_group: 'connectivity',
        display_position: '35'
      }
    }

    @definition.reload

    assert_equal 'connectivity', @definition.display_group
    assert_equal 35, @definition.display_position
  end

  test 'the index shows the group of each attribute' do
    get admin_custom_attributes_path

    assert_response :success
    assert_select 'td', text: I18n.t("custom_attribute_groups.#{@definition.display_group}")
  end
end
