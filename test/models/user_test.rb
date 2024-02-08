require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'profile_path' do
    assert_equal users(:one).profile_path, '/users/username1'
  end
end
