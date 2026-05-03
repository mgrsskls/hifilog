# frozen_string_literal: true

require 'test_helper'

class HistoryHelperTest < ActiveSupport::TestCase
  include HistoryHelper

  test 'get_history_possessions groups dated possession rows by calendar year with metadata' do
    user = users(:one)
    buckets = get_history_possessions(user.possessions)

    flattened = buckets.values.flatten

    assert_not_predicate flattened, :empty?

    flattened.each do |entry|
      assert_includes [:from, :to], entry[:type]
      assert entry[:date]
      assert_predicate entry[:presenter], :present?
      assert_respond_to entry[:presenter], :display_name
    end

    assert(buckets.keys.all?(Integer))
  end
end
