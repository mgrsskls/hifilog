# frozen_string_literal: true

require 'test_helper'

class FilterConstantsTest < ActiveSupport::TestCase
  test 'status codes and ISO country list stay stable' do
    assert_equal %w[discontinued continued], FilterConstants::STATUSES
    assert_operator FilterConstants::COUNTRY_CODES.size, :>, 200
    assert_includes FilterConstants::COUNTRY_CODES, 'DE'
    assert_predicate FilterConstants::STATUSES, :frozen?
    assert_predicate FilterConstants::COUNTRY_CODES, :frozen?
  end
end
