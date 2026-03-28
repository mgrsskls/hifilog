require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'profile_path' do
    assert_equal users(:visible).profile_path, '/users/username3'
  end

  test 'validations' do
    user = User.new
    assert_not user.valid?
    assert user.errors[:email].any?
    assert user.errors[:user_name].any?
  end

  test 'email uniqueness validation' do
    user = users(:one)
    duplicate = User.new(email: user.email, user_name: 'different_username')
    assert_not duplicate.valid?
    assert duplicate.errors[:email].any?
  end

  test 'email uniqueness case insensitive' do
    user = users(:one)
    duplicate = User.new(email: user.email.upcase, user_name: 'different_username')
    assert_not duplicate.valid?
  end

  test 'user_name uniqueness validation' do
    user = users(:one)
    duplicate = User.new(email: 'different@email.com', user_name: user.user_name)
    assert_not duplicate.valid?
    assert duplicate.errors[:user_name].any?
  end

  test 'user_name uniqueness case insensitive' do
    user = users(:one)
    duplicate = User.new(email: 'different@email.com', user_name: user.user_name.upcase)
    assert_not duplicate.valid?
  end

  test 'profile_visibility enum' do
    user = users(:one)
    user.profile_visibility = :hidden
    assert user.hidden?

    user.profile_visibility = :logged_in_only
    assert user.logged_in_only?

    user.profile_visibility = :visible
    assert user.visible?
  end

  test 'associations' do
    user = users(:one)
    assert_respond_to user, :possessions
    assert_respond_to user, :products
    assert_respond_to user, :setups
    assert_respond_to user, :bookmarks
    assert_respond_to user, :custom_products
    assert_respond_to user, :notes
    assert_respond_to user, :events
  end

  test 'display_name' do
    user = users(:one)
    assert_equal user.email, user.display_name
  end
end
