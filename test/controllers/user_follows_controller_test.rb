# frozen_string_literal: true

require 'test_helper'

class UserFollowsControllerTest < ActionDispatch::IntegrationTest
  test 'create requires sign in' do
    followed = users(:visible)
    assert_no_difference 'UserFollow.count' do
      post user_follows_path, params: { followed_id: followed.id }
    end
    assert_redirected_to new_user_session_path
  end

  test 'create follow' do
    sign_in users(:one)
    followed = users(:logged_in_only)

    assert_difference 'UserFollow.count', 1 do
      post user_follows_path, params: { followed_id: followed.id }
    end

    assert_redirected_to followed.profile_path
    assert_equal I18n.t('user_follow.messages.followed', name: followed.user_name), flash[:notice]
    assert users(:one).following?(followed)
  end

  test 'cannot follow self' do
    user = users(:one)
    sign_in user

    assert_no_difference 'UserFollow.count' do
      post user_follows_path, params: { followed_id: user.id }
    end

    assert_redirected_to dashboard_root_path
  end

  test 'cannot follow blocked user' do
    sign_in users(:one)
    blocked = users(:logged_in_only)
    UserBlock.create!(blocker: users(:one), blocked:)

    assert_no_difference 'UserFollow.count' do
      post user_follows_path, params: { followed_id: blocked.id }
    end

    assert_redirected_to blocked.profile_path
    assert_equal I18n.t(:generic_error_message), flash[:alert]
  end

  test 'cannot follow user who blocked you and the block is not disclosed' do
    sign_in users(:one)
    blocker = users(:logged_in_only)
    UserBlock.create!(blocker:, blocked: users(:one))

    assert_no_difference 'UserFollow.count' do
      post user_follows_path, params: { followed_id: blocker.id }
    end

    assert_redirected_to blocker.profile_path
    assert_equal I18n.t(:generic_error_message), flash[:alert]
  end

  test 'cannot follow hidden user and response matches nonexistent user' do
    sign_in users(:one)
    hidden = users(:hidden)

    assert_no_difference 'UserFollow.count' do
      post user_follows_path, params: { followed_id: hidden.id }
    end

    assert_redirected_to dashboard_root_path
    assert_equal I18n.t(:generic_error_message), flash[:alert]

    post user_follows_path, params: { followed_id: -1 }

    assert_redirected_to dashboard_root_path
    assert_equal I18n.t(:generic_error_message), flash[:alert]
  end

  test 'create falls back to profile when redirect_to is an external URL' do
    sign_in users(:one)
    followed = users(:logged_in_only)

    post user_follows_path, params: { followed_id: followed.id, redirect_to: 'https://evil.example.com/phish' }

    assert_redirected_to followed.profile_path
  end

  test 'destroy falls back to profile when redirect_to is an external URL' do
    follow = user_follows(:one_follows_visible)
    sign_in follow.follower

    delete user_follow_path(follow, redirect_to: 'https://evil.example.com/phish')

    assert_redirected_to follow.followed.profile_path
  end

  test 'destroy unfollow' do
    follow = user_follows(:one_follows_visible)
    sign_in follow.follower

    assert_difference 'UserFollow.count', -1 do
      delete user_follow_path(follow, redirect_to: dashboard_following_path)
    end

    assert_redirected_to dashboard_following_path
    assert_equal I18n.t('user_follow.messages.unfollowed', name: follow.followed.user_name), flash[:notice]
    assert_not follow.follower.following?(follow.followed)
  end

  test 'destroy unfollow hides followed_by_user activity' do
    follow = user_follows(:one_follows_visible)
    UserActivities::Recorder.followed_by_user(follow)
    activity = UserActivity.find_by!(user: follow.followed, subject: follow, verb: 'followed_by_user')
    sign_in follow.follower

    delete user_follow_path(follow, redirect_to: dashboard_following_path)

    assert activity.reload.hidden_at.present?
  end

  test 'followed user can remove follower' do
    follow = user_follows(:visible_follows_one)
    sign_in follow.followed

    assert_difference 'UserFollow.count', -1 do
      delete user_follow_path(follow, redirect_to: dashboard_followers_path)
    end

    assert_redirected_to dashboard_followers_path
    assert_equal I18n.t('user_follow.messages.removed_follower', name: follow.follower.user_name), flash[:notice]
    assert_not follow.follower.following?(follow.followed)
  end
end
