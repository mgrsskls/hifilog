# frozen_string_literal: true

require 'test_helper'

class FilterParamsBuilderTest < ActiveSupport::TestCase
  class Harness
    include FilterParamsBuilder

    attr_accessor :category, :sub_category

    def initialize(category: nil, sub_category: nil)
      @category = category
      @sub_category = sub_category
    end
  end

  setup do
    @harness = Harness.new(
      category: categories(:one),
      sub_category: sub_categories(:one)
    )
  end

  test 'build_filters keeps category sorting and mirrors params' do
    filters = @harness.build_filters({ sort: 'name_asc' })

    assert_equal categories(:one), filters[:category]
    assert_equal sub_categories(:one), filters[:sub_category]
    assert_equal 'name_asc', filters[:sort]
  end

  test 'build_product_filters parses diy_kit status and query' do
    params = ActionController::Parameters.new(
      products: {
        diy_kit: '1',
        status: 'discontinued',
        query: '  zoom  ',
        amplifier_channel_type: ['1']
      }
    ).permit!

    filters = @harness.build_product_filters(params.to_unsafe_hash)

    assert_equal '1', filters[:diy_kit]
    assert_equal 'discontinued', filters[:status]
    assert_equal '  zoom  ', filters[:query]
    custom = filters[:custom].respond_to?(:stringify_keys) ? filters[:custom].stringify_keys : filters[:custom]
    assert custom.key?('amplifier_channel_type')
  end

  test 'build_brand_filters rejects unknown country codes' do
    params = {
      brands: {
        country: 'XX',
        query: 'q',
        status: 'continued'
      }
    }

    filters = @harness.build_brand_filters(params)

    assert_not filters.key?(:country)
    assert_equal 'q', filters[:query]
    assert_equal 'continued', filters[:status]
  end

  test 'build_brand_filters uppercases iso country filters' do
    params = { brands: { country: 'de' } }
    filters = @harness.build_brand_filters(params)

    assert_equal 'de', filters[:country]
  end

  test 'build_filters omits category keys when absent' do
    empty = Harness.new
    filters = empty.build_filters({ sort: nil })

    assert_not filters.key?(:category)
    assert_not filters.key?(:sub_category)
  end

  test 'build_product_filters ignores diy_kit outside 0 or 1' do
    params = {
      products: {
        diy_kit: 'maybe',
        query: ''
      }
    }

    filters = @harness.build_product_filters(params)
    assert_not filters.key?(:diy_kit)
  end

  test 'build_product_filters ignores unsupported product status tokens' do
    params = { products: { status: 'mystery' } }
    filters = @harness.build_product_filters(params)

    assert_not filters.key?(:status)
  end

  test 'flatten_query_values nests values from nested hashes' do
    nested = ActionController::Parameters.new({ amplifier_channel_type: { nested: %w[a b] } }).permit!
    values = @harness.send(:flatten_query_values, nested)

    assert_includes values, 'a'
    assert_includes values, 'b'
  end

  test 'deep_except deletes nested Parameter keys safely' do
    params = ActionController::Parameters.new(
      product: { nested: { keep: '1', drop: '2' }, other: 'x' }
    ).permit!

    result = @harness.send(:deep_except, params, [:product, :nested, :drop])
    nested = result[:product][:nested]

    assert_equal '1', nested[:keep]
    assert_not nested.key?(:drop)
  end
end
