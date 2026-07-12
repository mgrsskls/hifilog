# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::FollowItems
  private

  def followed_by_user_activity_item(activity)
    follow = activity.subject
    return nil unless follow.is_a?(UserFollow)

    follower = follow.follower
    return nil unless follower

    meta = activity.metadata || {}
    # Hidden followers are shown by name only; their profile is not reachable.
    url = follower.hidden? ? nil : (meta['url'].presence || follower.profile_path)
    UserActivityTimeline::Item.new(
      verb: :followed_by_user,
      logged_at: activity.occurred_at,
      display_name: follower.user_name,
      url:,
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil,
      possession_id: nil,
      gallery_image: nil
    )
  end
end
