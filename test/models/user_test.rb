require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'profile_path' do
    assert_equal users(:one).profile_path, '/user/username1'
    assert_nil users(:no_user_name).profile_path
  end
end
