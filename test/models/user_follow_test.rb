# frozen_string_literal: true

require 'test_helper'

class UserFollowTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test 'valid follow' do
    follow = UserFollow.new(follower: users(:one), followed: users(:logged_in_only))
    assert follow.valid?
  end

  test 'cannot follow self' do
    follow = UserFollow.new(follower: users(:one), followed: users(:one))
    assert_not follow.valid?
    assert_includes follow.errors[:followed], 'is invalid'
  end

  test 'unique per follower and followed' do
    existing = user_follows(:one_follows_visible)
    duplicate = UserFollow.new(follower: existing.follower, followed: existing.followed)
    assert_not duplicate.valid?
  end

  test 'cannot follow blocked user' do
    follower = users(:one)
    followed = users(:logged_in_only)
    UserBlock.create!(blocker: follower, blocked: followed)

    follow = UserFollow.new(follower:, followed:)
    assert_not follow.valid?
    assert_includes follow.errors[:followed], 'is blocked'
  end

  test 'notify_followed_user enqueues email when follower profile is not hidden' do
    follower = users(:visible)
    followed = users(:without_anything)

    assert_enqueued_emails 1 do
      UserFollow.create!(follower:, followed:)
    end
  end

  test 'notify_followed_user enqueues when follower profile is hidden' do
    followed = users(:without_anything)

    assert_enqueued_emails 1 do
      UserFollow.create!(follower: users(:hidden), followed:)
    end
  end

  test 'notify_followed_user does not enqueue again after unfollow and re-follow' do
    follower = users(:visible)
    followed = users(:without_anything)

    follow = nil
    assert_enqueued_emails 1 do
      follow = UserFollow.create!(follower:, followed:)
    end

    follow.destroy

    assert_no_enqueued_emails do
      UserFollow.create!(follower:, followed:)
    end
  end

  test 'notify_followed_user does not enqueue when followed user opted out' do
    follower = users(:visible)
    followed = users(:without_anything)
    followed.update!(receives_follow_notifications: false)

    assert_no_enqueued_emails do
      UserFollow.create!(follower:, followed:)
    end
  end
end
