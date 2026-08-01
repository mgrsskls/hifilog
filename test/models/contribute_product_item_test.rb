# frozen_string_literal: true

require 'test_helper'

# contribute_product_items is product_items plus the completeness columns. The two view
# definitions duplicate their shared SELECT list rather than one selecting from the other —
# that would make every future `update_view :product_items` fail on the dependent view. The
# price of that decision is drift, so this test is what keeps the two in step.
class ContributeProductItemTest < ActiveSupport::TestCase
  CONTRIBUTE_ONLY_COLUMNS = %w[completeness specs_applicable specs_filled].freeze

  test 'carries every product_items column' do
    missing = ProductItem.column_names - ContributeProductItem.column_names

    assert_empty missing,
                 'db/views/contribute_product_items_v01.sql has drifted from product_items: ' \
                 "add #{missing.join(', ')} to it too"
  end

  test 'adds only the completeness columns' do
    extra = ContributeProductItem.column_names - ProductItem.column_names

    assert_equal CONTRIBUTE_ONLY_COLUMNS.sort, extra.sort,
                 'contribute_product_items should be product_items plus the completeness ' \
                 'columns and nothing else'
  end

  test 'product_items does not pay for the completeness columns' do
    CONTRIBUTE_ONLY_COLUMNS.each do |column|
      assert_not_includes ProductItem.column_names, column,
                          "#{column} is back on product_items — the catalogue view is meant to " \
                          'stay free of the highlighted-specs LATERAL'
    end
  end
end
