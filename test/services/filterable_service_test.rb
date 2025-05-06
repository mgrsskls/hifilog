require 'test_helper'

class DummyFilterable
  include FilterableService
end

class FilterableServiceTest < ActiveSupport::TestCase
  def setup
    @dummy = DummyFilterable.new
    @scope = Brand.all
  end

  test 'apply_letter_filter returns only brands with correct initial' do
    params = { letter: 'a' }
    result = @dummy.apply_letter_filter(@scope, params, 'brands.name')
    assert(result.all? { |b| b.name.downcase.starts_with?('a') })
  end
end
