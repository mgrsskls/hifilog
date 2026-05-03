# frozen_string_literal: true

require 'test_helper'

class FilterableServiceTest < ActiveSupport::TestCase
  class Harness
    include FilterableService
  end

  setup do
    @harness = Harness.new
  end

  test 'extract_category returns category and nested sub-category objects' do
    category = categories(:one)
    sub_category = sub_categories(:one)

    param = "#{category.friendly_id}[#{sub_category.friendly_id}]"

    extracted_category, extracted_sub_category = @harness.extract_category(param)

    assert_equal category, extracted_category
    assert_equal sub_category, extracted_sub_category

    assert_nil @harness.extract_category('')[0]
  end

  test 'extract_custom_attributes aligns with persisted sub-category custom records' do
    sub_category = SubCategory.includes(:custom_attributes).find(sub_categories(:one).id)

    custom = @harness.extract_custom_attributes(nil, sub_category)

    assert_equal sub_category.custom_attributes.ids.sort.uniq, custom.ids.sort.uniq
  end

  test 'build_custom_attributes_hash nests ranged metadata for richer inputs' do
    blueprint = [
      {
        label: 'Impedance',
        input_type: 'number'
      },
      {
        label: 'Topology',
        inputs: %w[triode pentode]
      }
    ]

    built = @harness.build_custom_attributes_hash(blueprint)

    serialized = JSON.generate(built)

    assert_includes serialized, 'Impedance'
    assert_includes serialized, 'triode'
    assert_includes serialized, 'Topology'
  end
end
