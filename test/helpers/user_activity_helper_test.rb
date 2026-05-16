# frozen_string_literal: true

require 'test_helper'

class UserActivityHelperTest < ActionView::TestCase
  include UserActivityHelper

  def h(string)
    ERB::Util.html_escape(string)
  end

  test 'user_activity_group_summary includes setup link for setup_product_added' do
    sample = UserActivityTimeline::Item.new(
      verb: :setup_product_added,
      logged_at: Time.current,
      display_name: 'Product X',
      url: '/p',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: 'My setup',
      setup_url: '/users/u/setups/9',
      setup_id: 9
    )
    group = UserActivityTimeline::Grouped.new(
      verb: :setup_product_added,
      logged_at: Time.current,
      items: [sample, sample, sample],
      event_past: nil
    )

    html = user_activity_group_summary(group)
    assert_includes html, 'href="/users/u/setups/9"'
    assert_includes html, 'My setup'
    assert_includes html, '3'
  end

  test 'added_to_collection period meta when period_from differs from possession created_at day' do
    created = Time.zone.local(2024, 1, 10, 12, 0, 0)
    item = UserActivityTimeline::Item.new(
      verb: :added_to_collection,
      logged_at: created,
      display_name: 'X',
      url: '/x',
      period_from: Date.new(2020, 6, 1),
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: created,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    assert_not_nil user_activity_item_meta_period(item)
  end

  test 'added_to_collection hides period meta when period_from matches possession created_at day' do
    created = Time.zone.local(2024, 1, 10, 12, 0, 0)
    item = UserActivityTimeline::Item.new(
      verb: :added_to_collection,
      logged_at: created,
      display_name: 'X',
      url: '/x',
      period_from: Date.new(2024, 1, 10),
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: created,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    assert_nil user_activity_item_meta_period(item)
  end

  test 'user_activity_product_link renders display name and url' do
    item = UserActivityTimeline::Item.new(
      verb: :added_to_collection,
      logged_at: Time.current,
      display_name: 'My amp',
      url: '/products/amp',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    html = user_activity_product_link(item)
    assert_includes html, 'My amp'
    assert_includes html, 'href="/products/amp"'
  end

  test 'user_activity_item_title escapes display name' do
    item = UserActivityTimeline::Item.new(
      verb: :added_to_collection,
      logged_at: Time.current,
      display_name: 'Evil<script>',
      url: '/safe',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    html = user_activity_item_title(item)
    assert_includes html, 'Evil'
    assert_not_includes html, '<script>'
    assert_includes html, '&lt;script&gt;'
  end

  test 'user_activity_item_title uses attended copy when event_past' do
    item = UserActivityTimeline::Item.new(
      verb: :event_attendance,
      logged_at: Time.current,
      display_name: 'Some event',
      url: '/events/2000/some-event',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: true,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    html = user_activity_item_title(item)
    assert_includes html, 'Attended'
    assert_includes html, 'Some event'
  end

  test 'user_activity_item_title uses published copy for setup_made_public' do
    item = UserActivityTimeline::Item.new(
      verb: :setup_made_public,
      logged_at: Time.current,
      display_name: 'Living room',
      url: '/u/x/setups/1',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    html = user_activity_item_title(item)
    assert_includes html, 'Living room'
    assert_includes html, 'Published'
    assert_includes html, 'listening setup'
  end

  test 'user_activity_group_summary for grouped collection' do
    sample = UserActivityTimeline::Item.new(
      verb: :added_to_collection,
      logged_at: Time.current,
      display_name: 'P',
      url: '/p',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )
    group = UserActivityTimeline::Grouped.new(
      verb: :added_to_collection,
      logged_at: Time.current,
      items: [sample, sample, sample],
      event_past: nil
    )

    html = user_activity_group_summary(group)
    assert_includes html, '3'
    assert_includes html, 'Added'
  end

  test 'user_activity_group_summary uses published summary for setup_made_public' do
    sample = UserActivityTimeline::Item.new(
      verb: :setup_made_public,
      logged_at: Time.current,
      display_name: 'S',
      url: '/s',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )
    group = UserActivityTimeline::Grouped.new(
      verb: :setup_made_public,
      logged_at: Time.current,
      items: [sample, sample, sample],
      event_past: nil
    )

    html = user_activity_group_summary(group)
    assert_includes html, '3'
    assert_includes html, 'Published'
    assert_includes html, 'listening setups'
  end

  test 'user_activity_icon renders svg for known verb' do
    html = user_activity_icon(:added_to_collection).to_s
    assert_includes html, '<svg'
  end

  test 'user_activity_icon uses collection list glyph for upcoming event attendance' do
    html = user_activity_icon(:event_attendance, event_upcoming: true).to_s
    assert_includes html, 'M8.25 6.75h12'
    assert_not_includes html, 'M6.75 3v2.25'
  end

  test 'user_activity_icon uses calendar glyph for past event attendance' do
    html = user_activity_icon(:event_attendance, event_upcoming: false).to_s
    assert_includes html, 'M6.75 3v2.25'
    assert_not_includes html, 'M8.25 6.75h12'
  end

  test 'user_activity_icon returns nil for unknown verb' do
    assert_nil user_activity_icon(:not_a_verb)
  end

  test 'moved_to_previous period meta when period_to differs from logged day' do
    logged = Time.zone.local(2026, 1, 10, 12, 0, 0)
    item = UserActivityTimeline::Item.new(
      verb: :moved_to_previous,
      logged_at: logged,
      display_name: 'X',
      url: '/x',
      period_from: Date.new(2010, 1, 1),
      period_to: Date.new(2020, 5, 5),
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    assert_not_nil user_activity_item_meta_period(item)
  end

  test 'user_activity_item_title for event attendance cancelled' do
    item = UserActivityTimeline::Item.new(
      verb: :event_attendance_cancelled,
      logged_at: Time.current,
      display_name: 'Cancelled show',
      url: '/e',
      period_from: nil,
      period_to: nil,
      event_start_date: nil,
      event_end_date: nil,
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )

    html = user_activity_item_title(item)
    assert_includes html, 'Cancelled show'
    assert_includes html, 'No longer attends'
  end
end
