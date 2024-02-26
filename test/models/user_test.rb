require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'profile_path' do
    assert_equal users(:visible).profile_path, '/users/username3'
  end
end
