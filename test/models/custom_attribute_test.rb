# frozen_string_literal: true

require 'test_helper'

class CustomAttributeTest < ActiveSupport::TestCase
  setup do
    @sub_category = sub_categories(:one)
  end

  test 'requires label presence' do
    record = CustomAttribute.new(highlighted: true, label: '')
    assert_not record.valid?
    assert record.errors.attribute_names.include?(:label)
  end

  test 'requires label uniqueness' do
    dup = CustomAttribute.new(
      highlighted: false,
      label: custom_attributes(:one).label,
      input_type: 'option'
    )

    dup.sub_categories << @sub_category
    assert_not dup.valid?
    assert dup.errors.attribute_names.include?(:label)
  end

  test 'requires highlighted presence' do
    record = CustomAttribute.new(
      label: 'unique_highlight_test_xyz',
      input_type: 'boolean'
    )

    record.highlighted = nil

    assert_not record.valid?
    assert record.errors.attribute_names.include?(:highlighted)
  end

  test 'units_must_be_valid rejects unknown units' do
    record = CustomAttribute.new(
      label: 'unique_units_xyz',
      highlighted: true,
      input_type: 'number',
      units: %w[km]
    )

    record.sub_categories << @sub_category
    assert_not record.valid?
    assert_match(/contain invalid values/, record.errors[:units].join(' '))
  end

  test 'inputs_must_be_valid rejects unknown inputs via units error key' do
    record = CustomAttribute.new(
      label: 'unique_inputs_xyz',
      highlighted: true,
      input_type: 'number',
      inputs: %w[width]
    )

    record.sub_categories << @sub_category
    assert_not record.valid?
    assert_match(/contain invalid values/, record.errors[:units].join(' '))
  end

  test 'before_validation compacts blanks on units and inputs arrays' do
    record = CustomAttribute.new(
      label: 'unique_compact_xyz',
      highlighted: true,
      input_type: 'number',
      units: ['cm', nil, '', 'in'],
      inputs: ['w', '', nil]
    )

    record.sub_categories << @sub_category
    assert record.valid?, record.errors.full_messages.to_sentence
    assert_equal %w[cm in], record.units.sort
    assert_equal ['w'], record.inputs
  end

  test 'before_save parses options when options is JSON string' do
    parsed = { '1' => 'x' }

    record = CustomAttribute.new(
      label: 'unique_json_options_xyz',
      highlighted: true,
      input_type: 'option',
      options: parsed.to_json
    )

    record.sub_categories << @sub_category
    record.save!

    assert_equal parsed, CustomAttribute.find_by(label: 'unique_json_options_xyz').options
  end

  test 'before_save sets options to nil when options blank after cast' do
    record = CustomAttribute.new(
      label: 'unique_nil_opts_xyz',
      highlighted: true,
      input_type: 'boolean',
      options: nil
    )

    record.sub_categories << @sub_category
    record.save!

    assert_nil CustomAttribute.find_by(label: 'unique_nil_opts_xyz').options
  end

  test 'all_cached returns an array of attributes' do
    list = CustomAttribute.all_cached

    assert_kind_of Array, list
    assert_equal CustomAttribute.count, list.size
  end
end
