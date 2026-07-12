# frozen_string_literal: true

require 'test_helper'

class UserFollowingTest < ActionDispatch::IntegrationTest
  setup do
    UserActivities::Backfill.run_all
  end

  test 'dashboard feed includes followed user activity with name' do
    follower = users(:one)
    followed = users(:without_anything)
    UserFollow.create!(follower:, followed:)

    travel_to Time.zone.local(2026, 8, 1, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:one), prev_owned: false)
    end

    sign_in follower
    get dashboard_root_path
    assert_response :success
    assert_match followed.user_name, @response.body
  end

  test 'following feed omits activities from before the follow was created' do
    follower = users(:one)
    followed = users(:without_anything)

    travel_to Time.zone.local(2026, 8, 1, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:one), prev_owned: false)
    end

    travel_to Time.zone.local(2026, 8, 2, 12, 0, 0) do
      UserFollow.create!(follower:, followed:)
    end

    travel_to Time.zone.local(2026, 8, 3, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:two), prev_owned: false)
    end

    followed_items = followed_user_items(follower, followed)

    assert_equal 1, followed_items.size
    assert_match products(:two).name, followed_items.first.display_name
    assert_no_match products(:one).name, followed_user_names(follower, followed)
  end

  test 'following feed includes followed user activity at exactly follow created_at' do
    follower = users(:one)
    followed = users(:without_anything)
    follow_time = Time.zone.local(2026, 8, 2, 12, 0, 0)
    follow = nil

    travel_to follow_time do
      follow = UserFollow.create!(follower:, followed:)
    end

    travel_to follow_time + 1.hour do
      possession = Possession.create!(user: followed, product: products(:two), prev_owned: false)
      activity = UserActivity.find_by!(user: followed, subject: possession, verb: 'added_to_collection')
      activity.update_column(:occurred_at, follow.created_at) # rubocop:disable Rails/SkipsModelValidations
    end

    followed_items = followed_user_items(follower, followed)

    assert_equal 1, followed_items.size
    assert_match products(:two).name, followed_items.first.display_name
  end

  test 'following feed keeps viewer own activities regardless of follow dates' do
    follower = users(:one)
    followed = users(:without_anything)

    travel_to Time.zone.local(2026, 8, 1, 12, 0, 0) do
      Possession.create!(user: follower, product: products(:diy_kit), prev_owned: false)
    end

    travel_to Time.zone.local(2026, 8, 2, 12, 0, 0) do
      UserFollow.create!(follower:, followed:)
    end

    viewer_items = flat_items(UserActivityTimeline.grouped_for_following(follower))
                   .select { |item| item.actor_user_id == follower.id }

    assert(viewer_items.any? { |item| item.display_name.include?(products(:diy_kit).name) })
  end

  test 'following feed after re-follow omits activities from before the new follow' do
    follower = users(:one)
    followed = users(:without_anything)
    follow = nil

    travel_to Time.zone.local(2026, 8, 2, 12, 0, 0) do
      follow = UserFollow.create!(follower:, followed:)
    end

    travel_to Time.zone.local(2026, 8, 3, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:two), prev_owned: false)
    end

    travel_to Time.zone.local(2026, 8, 4, 12, 0, 0) do
      follow.destroy!
    end

    travel_to Time.zone.local(2026, 8, 5, 12, 0, 0) do
      UserFollow.create!(follower:, followed:)
    end

    travel_to Time.zone.local(2026, 8, 6, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:diy_kit), prev_owned: false)
    end

    followed_items = followed_user_items(follower, followed)

    assert_equal 1, followed_items.size
    assert_match products(:diy_kit).name, followed_items.first.display_name
    assert_no_match products(:two).name, followed_user_names(follower, followed)
  end

  test 'grouped_for_following excludes hidden followed users' do
    follower = users(:one)
    followed = users(:without_anything)
    UserFollow.create!(follower:, followed:)

    travel_to Time.zone.local(2026, 8, 2, 12, 0, 0) do
      Possession.create!(user: followed, product: products(:two), prev_owned: false)
    end

    rows = UserActivityTimeline.grouped_for_following(follower)
    assert_includes actor_user_ids(rows), followed.id

    followed.update!(profile_visibility: :hidden)
    rows = UserActivityTimeline.grouped_for_following(follower)
    assert_not_includes actor_user_ids(rows), followed.id
  end

  test 'dashboard shows when someone started following the current user' do
    followed = users(:one)
    follower = users(:without_anything)
    UserFollow.create!(follower:, followed:)

    sign_in followed
    get dashboard_root_path
    assert_response :success
    assert_match 'started following you', @response.body
    assert_match follower.user_name, @response.body
  end

  test 'following feed does not reveal who follows the users you follow' do
    viewer = users(:one)
    followed = users(:visible) # viewer follows :visible via fixture
    third = users(:without_anything)

    UserFollow.create!(follower: third, followed:)
    UserFollow.create!(follower: users(:hidden), followed: viewer)

    items = flat_items(UserActivityTimeline.grouped_for_following(viewer))
    follow_actor_ids = items.select { |item| item.verb == :followed_by_user }.map(&:actor_user_id)

    assert_includes follow_actor_ids, users(:hidden).id, "expected the viewer's own followed_by_user row"
    assert_not_includes follow_actor_ids, third.id, "expected another user's followers to stay private"
  end

  test 'dashboard shows hidden follower by name without profile link' do
    followed = users(:one)
    follower = users(:hidden)
    UserFollow.create!(follower:, followed:)

    sign_in followed
    get dashboard_root_path
    assert_response :success
    assert_match 'started following you', @response.body
    assert_match follower.user_name, @response.body
    assert_select 'a[href=?]', follower.profile_path, count: 0
  end

  test 'public profile omits followed_by_user activities' do
    followed = users(:visible)
    follower = users(:without_anything)
    UserFollow.create!(follower:, followed:)

    get user_path(id: followed.user_name)
    assert_response :success
    assert_no_match 'started following you', @response.body
  end

  test 'following page lists followed users' do
    follow = user_follows(:one_follows_visible)
    sign_in follow.follower

    get dashboard_following_path
    assert_response :success
    assert_select '.FollowingList-item', minimum: 1
    assert_match follow.followed.user_name, @response.body
  end

  test 'followers page lists users who follow the current user' do
    follow = user_follows(:visible_follows_one)
    sign_in follow.followed

    get dashboard_followers_path
    assert_response :success
    assert_select '.FollowingList-item', minimum: 1
    assert_match follow.follower.user_name, @response.body
    assert_select 'form', text: /#{Regexp.escape(I18n.t('user_follow.remove_follower'))}/
    assert_select 'form', text: /#{Regexp.escape(I18n.t('user_follow.block'))}/
  end

  private

  def flat_items(rows)
    rows.flat_map do |row|
      row.is_a?(UserActivityTimeline::Grouped) ? row.items : [row.item]
    end
  end

  def actor_user_ids(rows)
    flat_items(rows).map(&:actor_user_id).compact
  end

  def followed_user_items(viewer, followed)
    flat_items(UserActivityTimeline.grouped_for_following(viewer))
      .select { |item| item.actor_user_id == followed.id }
  end

  def followed_user_names(viewer, followed)
    followed_user_items(viewer, followed).map(&:display_name).join
  end
end
