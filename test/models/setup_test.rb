require 'test_helper'

class SetupTest < ActiveSupport::TestCase
  test 'visibility' do
    assert_equal 'Public', setups(:one).visibility
    assert_equal 'Private', setups(:two).visibility
  end
end
