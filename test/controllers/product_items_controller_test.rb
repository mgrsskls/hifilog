# frozen_string_literal: true

require 'test_helper'

class ProductItemsControllerTest < ActionDispatch::IntegrationTest
  parameter_combinations = [
    { category: ['amplifiers', 'amplifiers[headphone-amplifiers]'] },
    { sort: ['name_asc'] },
    { status: ['discontinued'] },
    { country: ['DE'] },
    { diy_kit: ['1'] },
    { custom_attributes: [{ amplifier_channel_type: ['1'] }] },
    { query: ['atrium'] }
  ]

  (1..parameter_combinations.size).each do |n|
    parameter_combinations.combination(n).each do |params_group|
      values = params_group.map { |param| param.values.first }
      value_combinations = values.first.product(*values[1..])

      value_combinations.each do |combo|
        params = params_group.map(&:keys).flatten.zip(combo).to_h

        define_method("test_index_#{params}") do
          get products_url, params: params
          assert_response :success
        end
      end
    end
  end

  test 'index' do
    get products_url
    assert_response :success
  end
end
