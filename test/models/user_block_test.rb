# frozen_string_literal: true

require 'test_helper'

class UserBlockTest < ActiveSupport::TestCase
  test 'valid block' do
    block = UserBlock.new(blocker: users(:one), blocked: users(:visible))
    assert block.valid?
  end

  test 'cannot block self' do
    block = UserBlock.new(blocker: users(:one), blocked: users(:one))
    assert_not block.valid?
    assert_includes block.errors[:blocked], 'is invalid'
  end

  test 'unique per blocker and blocked' do
    UserBlock.create!(blocker: users(:one), blocked: users(:visible))
    duplicate = UserBlock.new(blocker: users(:one), blocked: users(:visible))
    assert_not duplicate.valid?
  end

  test 'creating block removes follow in both directions' do
    follow_out = user_follows(:one_follows_visible)
    follow_in = user_follows(:visible_follows_one)

    UserBlock.create!(blocker: users(:one), blocked: users(:visible))

    assert_not UserFollow.exists?(follow_out.id)
    assert_not UserFollow.exists?(follow_in.id)
  end
end
