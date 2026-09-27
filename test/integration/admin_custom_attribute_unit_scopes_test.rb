# frozen_string_literal: true

require 'test_helper'

# The admin form is the only place where the units of each sub category are chosen. See
# docs/custom-attributes.md, "Units per sub category".
class AdminCustomAttributeUnitScopesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in admin_users(:admin_user)
    @definition = custom_attributes(:four)
    @definition.update!(units: %w[lb kg g])
    link(sub_categories(:one)).update!(units: %w[lb kg])
    link(sub_categories(:two)).update!(units: %w[g])
  end

  test 'the form has a row for every sub category and a column for every unit' do
    get edit_admin_custom_attribute_path(@definition)

    assert_response :success
    field = "custom_attribute[unit_scopes][#{sub_categories(:one).id}][]"
    assert_select "input[type=checkbox][name='#{field}'][value='kg'][checked]"
    assert_select "input[type=checkbox][name='#{field}'][value='g']:not([checked])"
    # The columns of the units that are not ticked above are hidden.
    assert_select "td[data-unit-column='g']:not([hidden])"
    assert_select "td[data-unit-column='cm'][hidden]"
    # The row of a sub category that the attribute does not apply to is hidden.
    assert_select "tr[data-unit-scopes-row='#{sub_categories(:three).id}'][hidden]"
    assert_select "tr[data-unit-scopes-row='#{sub_categories(:one).id}']:not([hidden])"
  end

  test 'an update saves the ticked units of each sub category' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(unit_scopes: rows(one: %w[kg lb], two: %w[g]))
    }

    assert_equal %w[lb kg], link(sub_categories(:one)).units
    assert_equal %w[g], link(sub_categories(:two)).units
  end

  test 'an update refuses a sub category without a unit' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(unit_scopes: rows(one: %w[kg lb], two: []))
    }

    assert_response :unprocessable_content
    assert_match 'need at least one unit ticked for each category: Over-Ear Headphones', response.body
    assert_equal %w[g], link(sub_categories(:two)).reload.units
    # The form shows what the admin ticked.
    assert_select "input[name='custom_attribute[unit_scopes][#{sub_categories(:two).id}][]'][value='g']:not([checked])"
  end

  test 'a category ticked in the same submit gets its units in the same submit' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(
        sub_category_ids: ['', sub_categories(:one).id, sub_categories(:two).id, sub_categories(:three).id],
        unit_scopes: rows(one: %w[kg lb], two: %w[g], three: %w[g])
      )
    }

    assert_equal %w[g], link(sub_categories(:three)).units
  end

  test 'a unit removed above leaves the rows, and a row without a unit is refused' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(units: ['', 'lb', 'kg'], unit_scopes: rows(one: %w[kg lb g], two: %w[g]))
    }

    assert_response :unprocessable_content
    assert_match 'Over-Ear Headphones', response.body

    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(units: ['', 'lb', 'kg'], unit_scopes: rows(one: %w[kg lb g], two: %w[kg]))
    }

    assert_equal %w[lb kg], link(sub_categories(:one)).units
    assert_equal %w[kg], link(sub_categories(:two)).units
  end

  test 'the units above must convert to each other' do
    patch admin_custom_attribute_path(@definition), params: {
      custom_attribute: attributes(units: ['', 'kg', 'cm'])
    }

    assert_response :unprocessable_content
    assert_match 'do not convert to kg: cm', response.body
  end

  private

  def attributes(**overrides)
    {
      label: @definition.label, highlighted: @definition.highlighted ? '1' : '0', input_type: 'number',
      units: ['', 'lb', 'kg', 'g'], sub_category_ids: ['', sub_categories(:one).id, sub_categories(:two).id]
    }.merge(overrides)
  end

  # The params of the unit table, with the blank value that each row always sends.
  def rows(**units_by_fixture)
    units_by_fixture.to_h { |fixture, units| [sub_categories(fixture).id.to_s, [''] + units] }
  end

  def link(sub_category)
    CustomAttributeSubCategory.find_by!(custom_attribute: @definition, sub_category:)
  end
end
