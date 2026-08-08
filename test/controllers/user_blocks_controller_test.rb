# frozen_string_literal: true

require 'test_helper'

class UserBlocksControllerTest < ActionDispatch::IntegrationTest
  test 'blocked' do
    get dashboard_blocked_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    sign_in users(:one)
    blocked = users(:logged_in_only)
    user_block = UserBlock.create!(blocker: users(:one), blocked:)

    get dashboard_blocked_path
    assert_response :success
    assert_select 'h1', text: I18n.t('headings.blocked')
    assert_select 'a.Sidebar-link[href=?][aria-current="true"]', dashboard_blocked_path
    assert_select 'a.Sidebar-link[href=?][aria-current="false"]', dashboard_following_path
    assert_select 'nav .Tabs', count: 0
    assert_select '.FollowingList-item', minimum: 1
    assert_match blocked.user_name, @response.body
    assert_select 'form', text: /#{Regexp.escape(I18n.t('user_follow.unblock'))}/

    delete user_block_path(user_block, redirect_to: dashboard_blocked_path)
    assert_redirected_to dashboard_blocked_path

    get dashboard_blocked_path
    assert_select '.EmptyState', text: /#{Regexp.escape(I18n.t('user_follow.empty_state.no_blocked'))}/
  end

  test 'create requires sign in' do
    blocked = users(:visible)
    assert_no_difference 'UserBlock.count' do
      post user_blocks_path, params: { blocked_id: blocked.id }
    end
    assert_redirected_to new_user_session_path
  end

  test 'create block' do
    sign_in users(:one)
    blocked = users(:logged_in_only)

    assert_difference 'UserBlock.count', 1 do
      post user_blocks_path, params: { blocked_id: blocked.id, redirect_to: dashboard_followers_path }
    end

    assert_redirected_to dashboard_followers_path
    assert_equal I18n.t('user_follow.messages.blocked', name: blocked.user_name), flash[:notice]
    assert users(:one).blocked?(blocked)
  end

  test 'cannot block self' do
    user = users(:one)
    sign_in user

    assert_no_difference 'UserBlock.count' do
      post user_blocks_path, params: { blocked_id: user.id }
    end

    assert_redirected_to dashboard_followers_path
  end

  test 'create falls back to followers page when redirect_to is an external URL' do
    sign_in users(:one)
    blocked = users(:logged_in_only)

    post user_blocks_path, params: { blocked_id: blocked.id, redirect_to: 'https://evil.example.com/phish' }

    assert_redirected_to dashboard_followers_path
  end

  test 'destroy unblock' do
    block = UserBlock.create!(blocker: users(:one), blocked: users(:logged_in_only))
    sign_in block.blocker

    assert_difference 'UserBlock.count', -1 do
      delete user_block_path(block, redirect_to: dashboard_followers_path)
    end

    assert_redirected_to dashboard_followers_path
    assert_equal I18n.t('user_follow.messages.unblocked', name: block.blocked.user_name), flash[:notice]
    assert_not block.blocker.blocked?(block.blocked)
  end
end
