# frozen_string_literal: true

require 'test_helper'

class UserActivityTimelineTest < ActiveSupport::TestCase
  setup do
    UserActivities::Backfill.run_all
  end

  test 'grouped_for returns rows for user with fixtures' do
    rows = UserActivityTimeline.grouped_for(users(:one))
    assert rows.is_a?(Array)
    assert rows.any?
    assert(rows.all? { |r| r.is_a?(UserActivityTimeline::Grouped) || r.is_a?(UserActivityTimeline::Single) })
  end

  test 'groups three collection adds on the same calendar day' do
    user = users(:without_anything)
    t = Time.zone.local(2026, 2, 10, 11, 0, 0)
    travel_to t do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
      Possession.create!(user: user, product: products(:two), prev_owned: false)
      Possession.create!(user: user, product: products(:diy_kit), prev_owned: false)
    end

    rows = UserActivityTimeline.grouped_for(user)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :added_to_collection }
    assert grouped
    assert_equal 3, grouped.items.size
  end

  test 'same-day collection adds split by interleaved activity stay separate runs' do
    user = users(:without_anything)
    day = Time.zone.local(2026, 7, 15, 10, 0, 0)
    travel_to(day) { Possession.create!(user: user, product: products(:one), prev_owned: false) }
    travel_to(day + 1.minute) { Possession.create!(user: user, product: products(:two), prev_owned: false) }
    travel_to(day + 2.minutes) { Possession.create!(user: user, product: products(:diy_kit), prev_owned: false) }
    travel_to(day + 3.minutes) do
      CustomProduct.create!(
        name: 'Interleaved CP',
        user: user,
        sub_categories: [sub_categories(:one)]
      )
    end
    travel_to(day + 4.minutes) do
      Possession.create!(user: user, product: products(:with_custom_attributes), prev_owned: false)
    end
    travel_to(day + 5.minutes) do
      Possession.create!(user: user, product: products(:without_custom_attributes), prev_owned: false)
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :added_to_collection }
    assert grouped, 'expected first batch of three adds to form one group'
    assert_equal 3, grouped.items.size
    assert_equal day + 2.minutes, grouped.logged_at

    collection_singles = rows.select do |r|
      r.is_a?(UserActivityTimeline::Single) && r.item.verb == :added_to_collection
    end
    assert_equal 2, collection_singles.size
  end

  test 'grouped_for limit caps returned rows' do
    user = users(:without_anything)
    products = [products(:one), products(:two), products(:diy_kit)]
    t = Time.zone.local(2026, 4, 1, 10, 0, 0)
    12.times do |i|
      travel_to(t + i.days) do
        Possession.create!(user: user, product: products[i % 3], prev_owned: false)
      end
    end

    all_rows = UserActivityTimeline.grouped_for(user)
    limited_rows = UserActivityTimeline.grouped_for(user, limit: 10)

    assert_operator all_rows.size, :>=, 12
    assert_equal 10, limited_rows.size
    assert_equal timeline_row_keys(all_rows.first(10)), timeline_row_keys(limited_rows)
  end

  test 'grouped_for limit matches full timeline when fetch cap is exceeded' do
    user = users(:without_anything)
    products = [products(:one), products(:two), products(:diy_kit)]
    t = Time.zone.local(2026, 4, 1, 10, 0, 0)
    12.times do |i|
      travel_to(t + i.days) do
        Possession.create!(user: user, product: products[i % 3], prev_owned: false)
      end
    end

    timeline = UserActivityTimeline.new(user, time_zone: Time.zone, limit: 10)
    timeline.define_singleton_method(:activities_fetch_limit) { 5 }

    limited = timeline.send(:grouped_rows)
    full = UserActivityTimeline.grouped_for(user).first(10)

    assert_equal 10, limited.size
    assert_equal timeline_row_keys(full), timeline_row_keys(limited)
  end

  test 'grouped_for limit uses capped fetch when feed fits within fetch limit' do
    user = users(:without_anything)
    travel_to Time.zone.local(2026, 4, 1, 10, 0, 0) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end

    timeline = UserActivityTimeline.new(user, time_zone: Time.zone, limit: 10)
    feed_scope = user.user_activities.visible.for_feed
    assert_operator feed_scope.count, :<, timeline.send(:activities_fetch_limit)

    limited = UserActivityTimeline.grouped_for(user, limit: 10)
    full = UserActivityTimeline.grouped_for(user)

    assert_equal timeline_row_keys(full), timeline_row_keys(limited)
  end

  test 'fewer than threshold collection adds stay as single rows' do
    user = users(:without_anything)
    t = Time.zone.local(2026, 3, 5, 9, 0, 0)
    travel_to t do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end

    rows = UserActivityTimeline.grouped_for(user)
    collection_rows = rows.select do |r|
      r.is_a?(UserActivityTimeline::Single) && r.item.verb == :added_to_collection
    end
    assert_equal 2, collection_rows.size
  end

  test 'does not raise when possession has nil created_at' do
    possession = possessions(:current_product)
    # Column is nullable in schema; legacy rows can have null +created_at+.
    possession.update_column(:created_at, nil) # rubocop:disable Rails/SkipsModelValidations

    assert_nothing_raised do
      UserActivityTimeline.grouped_for(users(:one))
    end
  ensure
    possession.update_column(:created_at, Time.zone.local(2024, 1, 1, 12, 0, 0)) # rubocop:disable Rails/SkipsModelValidations
  end

  test 'epoch created_at does not surface as 1970; logged uses user; period_from differs for meta' do
    possession = possessions(:current_product)
    user = users(:one)
    possession.update_columns( # rubocop:disable Rails/SkipsModelValidations
      created_at: Time.utc(1970, 1, 1, 0, 0, 0),
      period_from: Time.zone.local(2018, 6, 15, 12, 0, 0)
    )

    items = timeline_items_for(users(:one).reload)
    collection = items.find { |i| i.verb == :added_to_collection && i.url == possession_presenter_path(possession) }

    assert_equal user.reload.created_at.to_date, collection.logged_at.to_date
    assert_equal Date.new(2018, 6, 15), collection.period_from.to_date
  ensure
    possession.update_columns( # rubocop:disable Rails/SkipsModelValidations
      created_at: Time.zone.local(2024, 1, 1, 12, 0, 0),
      period_from: Date.new(2020, 1, 1)
    )
  end

  test 'moved_to_previous_at emits collection add then moved, both logged' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 5, 20, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    possession.update!(
      prev_owned: true,
      moved_to_previous_at: Time.zone.local(2026, 5, 20, 15, 0, 0)
    )

    items = timeline_items_for(user.reload)
    verbs = items.select { |i| i.url == possession_presenter_path(possession) }.map(&:verb).sort

    assert_equal [:added_to_collection, :moved_to_previous], verbs
    collection = items.find { |i| i.verb == :added_to_collection && i.url == possession_presenter_path(possession) }
    moved = items.find { |i| i.verb == :moved_to_previous && i.url == possession_presenter_path(possession) }
    assert_equal Time.zone.local(2026, 5, 20, 10, 0, 0), collection.logged_at
    assert_equal Time.zone.local(2026, 5, 20, 15, 0, 0), moved.logged_at
  end

  test 'update to previous without explicit moved_to_previous_at still emits move pair' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 11, 1, 9, 0, 0)) do
      possession = Possession.create!(user: user, product: products(:diy_kit), prev_owned: false)
      possession.update!(prev_owned: true)

      assert possession.reload.moved_to_previous_at.present?

      items = timeline_items_for(user.reload)
      verbs = items.select { |i| i.url == possession_presenter_path(possession) }.map(&:verb).sort

      assert_equal [:added_to_collection, :moved_to_previous], verbs
    end
  end

  test 'prev_owned without moved_to_previous_at is added_to_previous only' do
    user = users(:without_anything)
    possession = Possession.create!(
      user: user,
      product: products(:diy_kit),
      prev_owned: true
    )
    assert_nil possession.reload.moved_to_previous_at

    items = timeline_items_for(user.reload)
    match = items.select { |i| i.url == possession_presenter_path(possession) }

    assert_equal [:added_to_previous], match.map(&:verb).uniq
  end

  test 'prev_owned with period_to and no moved_to_previous_at uses moved activity' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2022, 8, 3, 12, 0, 0)) do
      Possession.create!(
        user: user,
        product: products(:with_custom_attributes),
        prev_owned: true,
        period_to: Date.new(2019, 3, 1)
      )
    end
    assert_nil possession.reload.moved_to_previous_at

    items = timeline_items_for(user.reload)
    match = items.select { |i| i.url == possession_presenter_path(possession) }

    assert_equal [:moved_to_previous], match.map(&:verb).uniq
    assert_equal Date.new(2022, 8, 3), match.first.logged_at.to_date
    assert_equal Date.new(2019, 3, 1), match.first.period_to.to_date
  end

  test 'suppresses collection add when custom product possession is created in merge window' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 4, 1, 12, 0, 0)) do
      cp = CustomProduct.create!(
        name: 'merge-window-cp',
        user: user,
        sub_categories: [sub_categories(:one)]
      )
      Possession.create!(user: user, custom_product: cp, prev_owned: false)
    end
    possession.update!(
      prev_owned: true,
      moved_to_previous_at: Time.zone.local(2026, 4, 1, 14, 0, 0)
    )

    items = timeline_items_for(user.reload)
    match = items.select { |i| i.display_name == 'merge-window-cp' }
    verbs = match.map(&:verb).uniq.sort

    assert_includes verbs, :moved_to_previous
    assert_includes verbs, :custom_product_created
    assert_not_includes verbs, :added_to_collection
  end

  test 'event attendance past and upcoming same day are separate clusters' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 8, 1, 12, 0, 0)) do
      past_event = Event.create!(
        name: 'Timeline past event',
        address: 'a',
        url: 'https://example.test/past',
        country_code: 'DE',
        start_date: Date.new(1990, 6, 1),
        end_date: Date.new(1990, 6, 2)
      )
      upcoming_event = Event.create!(
        name: 'Timeline upcoming event',
        address: 'a',
        url: 'https://example.test/up',
        country_code: 'DE',
        start_date: Time.zone.today + 400,
        end_date: Time.zone.today + 401
      )
      EventAttendee.create!(user: user, event: past_event)
      EventAttendee.create!(user: user, event: upcoming_event)
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    event_rows = rows.select do |r|
      (r.is_a?(UserActivityTimeline::Single) && r.item.verb == :event_attendance) ||
        (r.is_a?(UserActivityTimeline::Grouped) && r.verb == :event_attendance)
    end

    assert_equal 2, event_rows.size
    past_row = event_rows.find { |r| (r.is_a?(UserActivityTimeline::Single) ? r.item : r.items.first).event_past }
    upcoming_row = event_rows.find { |r| !(r.is_a?(UserActivityTimeline::Single) ? r.item : r.items.first).event_past }

    assert past_row
    assert upcoming_row
    assert upcoming_row.event_upcoming?
    assert_not past_row.event_upcoming?
  end

  test 'groups three past event attendances logged the same calendar day' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 9, 2, 11, 0, 0)) do
      3.times do |i|
        e = Event.create!(
          name: "Grouped past #{i}",
          address: 'a',
          url: "https://example.test/g#{i}",
          country_code: 'DE',
          start_date: Date.new(1985, 1, 1) + i.days,
          end_date: Date.new(1985, 1, 2) + i.days
        )
        EventAttendee.create!(user: user, event: e)
      end
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :event_attendance }
    assert grouped
    assert_equal 3, grouped.items.size
    assert(grouped.items.all?(&:event_past))
    assert grouped.event_past
  end

  test 'event RSVP before event start keeps will attend copy when event is calendar-past' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2019, 1, 1, 10, 0, 0)) do
      Event.create!(
        name: 'Festival RSVP early',
        address: 'a',
        url: 'https://example.test/fest-early',
        country_code: 'DE',
        start_date: Date.new(2025, 7, 1),
        end_date: Date.new(2025, 7, 3)
      )
    end
    travel_to(Time.zone.local(2019, 1, 1, 10, 0, 0)) do
      EventAttendee.create!(user: user, event: event)
    end

    travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) do
      assert_predicate event.reload, :discontinued?

      item = timeline_items_for(user.reload).find do |i|
        i.verb == :event_attendance && i.display_name == 'Festival RSVP early'
      end
      assert_not item.event_past, 'RSVP before event start should not use logged-as-attended copy'
    end
  end

  test 'event RSVP on or after event start uses logged as attended copy' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2025, 7, 2, 10, 0, 0)) do
      Event.create!(
        name: 'Festival RSVP during',
        address: 'a',
        url: 'https://example.test/fest-during',
        country_code: 'DE',
        start_date: Date.new(2025, 7, 1),
        end_date: Date.new(2025, 7, 3)
      )
    end
    travel_to(Time.zone.local(2025, 7, 2, 10, 0, 0)) do
      EventAttendee.create!(user: user, event: event)
    end

    item = timeline_items_for(user.reload).find do |i|
      i.verb == :event_attendance && i.display_name == 'Festival RSVP during'
    end
    assert item.event_past
  end

  test 'private setup is excluded from timeline even when setup_created row exists' do
    UserActivities::Backfill.run_all
    assert UserActivity.exists?(
      user: users(:one),
      subject: setups(:two),
      verb: 'setup_created'
    )

    items = timeline_items_for(users(:one))
    assert_not(items.any? { |i| [:setup_created, :setup_made_public].include?(i.verb) && i.display_name == 'two' })
  end

  test 'public setup appears in timeline' do
    UserActivities::Backfill.run_all
    items = timeline_items_for(users(:one))
    assert(items.any? { |i| i.verb == :setup_created && i.display_name == 'one' })
  end

  test 'setup created private then made public shows only setup_made_public timeline item' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 10, 1, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Same day public', private: true)
    end
    travel_to(Time.zone.local(2026, 10, 1, 9, 0, 0)) do
      setup.update!(private: false)
    end

    items = timeline_items_for(user.reload).select { |i| i.display_name == 'Same day public' }
    assert_equal 1, items.size
    assert_equal :setup_made_public, items.first.verb
  end

  test 'consecutive duplicate activity for same subject keeps newest timeline item only' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 10, 5, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Toggle pub', private: true)
    end
    travel_to(Time.zone.local(2026, 10, 5, 9, 0, 0)) do
      setup.update!(private: false)
    end
    travel_to(Time.zone.local(2026, 10, 5, 10, 0, 0)) do
      setup.update!(private: true)
    end
    travel_to(Time.zone.local(2026, 10, 5, 11, 0, 0)) do
      setup.update!(private: false)
    end

    items = timeline_items_for(user.reload).select do |i|
      i.display_name == 'Toggle pub' && i.verb == :setup_made_public
    end
    assert_equal 1, items.size
    assert_equal Time.zone.local(2026, 10, 5, 11, 0, 0), items.first.logged_at
  end

  test 'same verb and subject separated by another activity keeps both timeline items' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 10, 6, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Split pub', private: true)
    end
    travel_to(Time.zone.local(2026, 10, 6, 9, 0, 0)) do
      setup.update!(private: false)
    end
    travel_to(Time.zone.local(2026, 10, 6, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    travel_to(Time.zone.local(2026, 10, 6, 11, 0, 0)) do
      setup.update!(private: true)
    end
    travel_to(Time.zone.local(2026, 10, 6, 12, 0, 0)) do
      setup.update!(private: false)
    end

    items = timeline_items_for(user.reload).select { |i| i.display_name == 'Split pub' && i.verb == :setup_made_public }
    assert_equal 2, items.size
  end

  test 'three setups created public same day do not merge into one grouped card' do
    user = users(:without_anything)
    t = Time.zone.local(2026, 10, 20, 8, 0, 0)
    travel_to(t) do
      Setup.create!(user: user, name: 'S1', private: false)
      Setup.create!(user: user, name: 'S2', private: false)
      Setup.create!(user: user, name: 'S3', private: false)
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :setup_created }
    assert_nil grouped

    singles = rows.select do |r|
      r.is_a?(UserActivityTimeline::Single) && r.item.verb == :setup_created && %w[S1 S2
                                                                                   S3].include?(r.item.display_name)
    end
    assert_equal 3, singles.size
  end

  test 'destroyed public setup remains visible from snapshot metadata' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 11, 10, 12, 0, 0)) do
      Setup.create!(user: user, name: 'Will be deleted', private: false)
    end
    assert_predicate UserActivity.where(user: user, subject: setup, verb: 'setup_created'), :exists?

    setup.destroy!

    items = timeline_items_for(user.reload)
    assert(items.any? do |i|
      i.display_name == 'Will be deleted' && [:setup_created, :setup_made_public].include?(i.verb)
    end)
  end

  test 'destroying event attendee records cancellation in timeline' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2026, 12, 1, 10, 0, 0)) do
      Event.create!(
        name: 'RSVP then cancel',
        address: 'a',
        url: 'https://example.test/rsvp-cancel',
        country_code: 'DE',
        start_date: Date.new(2027, 1, 1),
        end_date: Date.new(2027, 1, 2)
      )
    end
    attendee = EventAttendee.create!(user: user, event: event)
    assert UserActivity.exists?(user: user, subject: attendee, verb: 'event_attendance')

    assert_difference(-> { UserActivity.where(user: user, verb: 'event_attendance_cancelled').count }, 1) do
      attendee.destroy!
    end

    item = timeline_items_for(user.reload).find do |i|
      i.verb == :event_attendance_cancelled && i.display_name == 'RSVP then cancel'
    end
    assert item
  end

  test 'grouped_for time_zone affects event_past at calendar boundaries' do
    user = users(:without_anything)
    travel_to(Time.utc(2025, 6, 30, 15, 0, 0)) do
      event = Event.create!(
        name: 'TZ boundary event',
        address: 'a',
        url: 'https://example.test/tz-bound',
        country_code: 'DE',
        start_date: Date.new(2025, 7, 1),
        end_date: Date.new(2025, 7, 2)
      )
      EventAttendee.create!(user: user, event: event)
    end

    item_utc = flat_timeline_items_for(user.reload, time_zone: ActiveSupport::TimeZone['UTC'])
               .find { |i| i.verb == :event_attendance && i.display_name == 'TZ boundary event' }

    item_tokyo = flat_timeline_items_for(user.reload, time_zone: ActiveSupport::TimeZone['Asia/Tokyo'])
                 .find { |i| i.verb == :event_attendance && i.display_name == 'TZ boundary event' }

    assert_not item_utc.event_past
    assert item_tokyo.event_past
  end

  test 'timeline still shows custom product activity when product is deleted' do
    user = users(:without_anything)
    cp = travel_to(Time.zone.local(2026, 2, 15, 11, 0, 0)) do
      CustomProduct.create!(
        name: 'Deleted CP timeline',
        user: user,
        sub_categories: [sub_categories(:one)]
      )
    end
    assert UserActivity.exists?(user: user, subject: cp, verb: 'custom_product_created')

    cp.destroy!

    item = timeline_items_for(user.reload).find do |i|
      i.verb == :custom_product_created && i.display_name == 'Deleted CP timeline'
    end
    assert item
  end

  test 'event attendance cancelled survives event deletion using metadata' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2026, 3, 1, 12, 0, 0)) do
      Event.create!(
        name: 'Cancel then delete event',
        address: 'a',
        url: 'https://example.test/cancel-del',
        country_code: 'DE',
        start_date: Date.new(2027, 3, 1),
        end_date: Date.new(2027, 3, 2)
      )
    end
    UserActivities::Recorder.event_attendance_cancelled(user: user, event: event)
    event.destroy!

    item = timeline_items_for(user.reload).find do |i|
      i.verb == :event_attendance_cancelled && i.display_name == 'Cancel then delete event'
    end
    assert item
  end

  test 'setup_product_added groups three adds per setup separately on the same day' do
    user = users(:without_anything)
    day = Time.zone.local(2026, 12, 20, 9, 0, 0)
    setup_a = travel_to(day) { Setup.create!(user: user, name: 'Cluster A', private: false) }

    [products(:one), products(:two), products(:diy_kit)].each_with_index do |product, i|
      travel_to(day + i.hours) do
        possession = Possession.create!(user: user, product: product, prev_owned: false)
        SetupPossession.create!(setup: setup_a, possession: possession)
      end
    end

    setup_b = travel_to(day + 3.hours) { Setup.create!(user: user, name: 'Cluster B', private: false) }

    [
      products(:with_custom_attributes),
      products(:without_custom_attributes),
      products(:with_variants)
    ].each_with_index do |product, i|
      travel_to(day + (i + 3).hours) do
        possession = Possession.create!(user: user, product: product, prev_owned: false)
        SetupPossession.create!(setup: setup_b, possession: possession)
      end
    end

    # Possession sync also writes +added_to_collection+, which interleaves in the feed and breaks contiguous
    # +setup_product_added+ runs; this test targets grouping for setup membership lines only.
    UserActivity.where(user: user, verb: 'added_to_collection').delete_all

    rows = UserActivityTimeline.grouped_for(user.reload)
    grouped_added = rows.select { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :setup_product_added }
    assert_equal 2, grouped_added.size
    assert(grouped_added.all? { |g| g.items.size == 3 })
    assert_equal [setup_a.id, setup_b.id].sort, grouped_added.map { |g| g.items.first.setup_id }.sort
  end

  test 'setup_product_added two per setup same day stays ungrouped' do
    user = users(:without_anything)
    day = Time.zone.local(2026, 12, 21, 9, 0, 0)
    setup_a = travel_to(day) { Setup.create!(user: user, name: 'Two A', private: false) }
    setup_b = travel_to(day) { Setup.create!(user: user, name: 'Two B', private: false) }

    [products(:one), products(:two)].each_with_index do |product, i|
      travel_to(day + i.hours) do
        possession = Possession.create!(user: user, product: product, prev_owned: false)
        SetupPossession.create!(setup: setup_a, possession: possession)
      end
    end

    [products(:diy_kit), products(:with_custom_attributes)].each_with_index do |product, i|
      travel_to(day + (i + 2).hours) do
        possession = Possession.create!(user: user, product: product, prev_owned: false)
        SetupPossession.create!(setup: setup_b, possession: possession)
      end
    end

    UserActivity.where(user: user, verb: 'added_to_collection').delete_all

    rows = UserActivityTimeline.grouped_for(user.reload)
    singles = rows.select { |r| r.is_a?(UserActivityTimeline::Single) && r.item.verb == :setup_product_added }
    assert_equal 4, singles.size
    assert_not(
      rows.any? { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :setup_product_added }
    )
  end

  test 'setup_product_removed groups three removals same setup when contiguous in feed' do
    user = users(:without_anything)
    day = Time.zone.local(2026, 12, 22, 9, 0, 0)
    setup = travel_to(day) { Setup.create!(user: user, name: 'Remove cluster', private: false) }
    possessions = []
    [products(:one), products(:two), products(:diy_kit)].each_with_index do |product, i|
      travel_to(day + i.hours) do
        possessions << Possession.create!(user: user, product: product, prev_owned: false)
        SetupPossession.create!(setup: setup, possession: possessions.last)
      end
    end
    UserActivity.where(user: user, verb: 'added_to_collection').delete_all

    travel_to(day + 3.hours) do
      possessions.reverse_each { |p| setup.setup_possessions.find_by!(possession: p).destroy! }
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    grouped = rows.find { |r| r.is_a?(UserActivityTimeline::Grouped) && r.verb == :setup_product_removed }
    assert grouped
    assert_equal 3, grouped.items.size
    assert_equal setup.id, grouped.items.first.setup_id
  end

  test 'same logged_at lists setup_product_added before setup_created' do
    user = users(:without_anything)
    t = Time.zone.local(2026, 8, 15, 14, 30, 0)
    setup = nil
    travel_to t do
      setup = Setup.create!(user: user, name: 'Same instant setup', private: false)
      possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
      SetupPossession.create!(setup: setup, possession: possession)
    end

    UserActivity.where(user: user, verb: %w[setup_created setup_product_added]).find_each do |a|
      a.update_column(:occurred_at, t) # rubocop:disable Rails/SkipsModelValidations
    end

    rows = UserActivityTimeline.grouped_for(user.reload)
    idx_created = rows.index do |r|
      r.is_a?(UserActivityTimeline::Single) &&
        r.item.verb == :setup_created &&
        r.item.display_name == 'Same instant setup'
    end
    idx_product = rows.index do |r|
      verb = r.is_a?(UserActivityTimeline::Grouped) ? r.verb : r.item.verb
      verb == :setup_product_added &&
        (r.is_a?(UserActivityTimeline::Grouped) ? r.items.first : r.item).setup_name == 'Same instant setup'
    end

    assert idx_created
    assert idx_product
    assert_operator idx_product, :<, idx_created
  end

  test 'setup_product_added while setup was private is omitted from timeline after setup is public' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 6, 10, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Private staging setup', private: true)
    end
    travel_to(Time.zone.local(2026, 6, 10, 9, 0, 0)) do
      possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
      SetupPossession.create!(setup: setup, possession: possession)
    end
    travel_to(Time.zone.local(2026, 6, 10, 11, 0, 0)) do
      setup.update!(private: false)
    end

    assert UserActivity.exists?(user: user, subject: setup, verb: 'setup_product_added')
    product_act = UserActivity.find_by!(user: user, subject: setup, verb: 'setup_product_added')
    assert ActiveModel::Type::Boolean.new.cast(product_act.metadata['private'])
    assert ActiveModel::Type::Boolean.new.cast(product_act.metadata['recorded_while_setup_private'])

    items = timeline_items_for(user.reload)
    assert_not(
      items.any? { |i| i.verb == :setup_product_added && i.setup_name == 'Private staging setup' }
    )
    assert_not(items.any? { |i| i.display_name == 'Private staging setup' && i.verb == :setup_created })
    assert(items.any? { |i| i.display_name == 'Private staging setup' && i.verb == :setup_made_public })
  end

  test 'setup_product_added setup link uses current profile username after rename' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 6, 20, 10, 0, 0)) do
      Setup.create!(user: user, name: 'Rename URL setup', private: false)
    end
    possession = Possession.create!(user: user, product: products(:one), prev_owned: false)
    SetupPossession.create!(setup: setup, possession: possession)

    item_before = timeline_items_for(user.reload).find { |i| i.verb == :setup_product_added }
    assert_includes item_before.setup_url, '/users/username5/'

    user.update!(user_name: 'renamed_activity_user')

    item_after = timeline_items_for(user.reload).find { |i| i.verb == :setup_product_added }
    assert_includes item_after.setup_url, '/users/renamed_activity_user/'
    assert_includes item_after.url, '/products/'
  end

  test 'possession_image_deleted is persisted but not shown on activity timeline' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 8, 3, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end
    travel_to(Time.zone.local(2026, 8, 3, 11, 0, 0)) do
      possession.update!(images: [one_by_one_png_upload(filename: 'to-delete.png')])
    end
    attachment_id = possession.images.attachments.sole.id
    possession.purge_images_by_id!([attachment_id])

    assert UserActivity.exists?(user: user, subject: possession, verb: 'possession_image_deleted')
    items = timeline_items_for(user.reload)
    assert_not(items.any? { |i| i.verb == :possession_image_deleted })
  end

  test 'possession_image_uploaded is persisted but not shown on activity timeline' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 8, 2, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end
    travel_to(Time.zone.local(2026, 8, 2, 11, 0, 0)) do
      possession.update!(images: [one_by_one_png_upload(filename: 'feed-hidden.png')])
    end

    assert UserActivity.exists?(user: user, subject: possession, verb: 'possession_image_uploaded')
    items = timeline_items_for(user.reload)
    assert_not(items.any? { |i| i.verb == :possession_image_uploaded })
  end

  test 'avatar_uploaded is persisted but not shown on activity timeline' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 9, 2, 11, 0, 0)) do
      user.update!(avatar: one_by_one_png_upload(filename: 'feed-hidden-avatar.png'))
    end

    assert UserActivity.exists?(user: user, subject: user, verb: 'avatar_uploaded')
    items = timeline_items_for(user.reload)
    assert_not(items.any? { |i| i.verb == :avatar_uploaded })
  end

  test 'avatar_deleted is persisted but not shown on activity timeline' do
    user = users(:without_anything)
    travel_to(Time.zone.local(2026, 9, 3, 10, 0, 0)) do
      user.update!(avatar: one_by_one_png_upload(filename: 'to-delete-avatar.png'))
    end
    user.purge_avatar!

    assert UserActivity.exists?(user: user, subject: user, verb: 'avatar_deleted')
    items = timeline_items_for(user.reload)
    assert_not(items.any? { |i| i.verb == :avatar_deleted })
  end

  test 'setup_made_private is persisted but not shown on activity timeline' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 6, 11, 8, 0, 0)) do
      Setup.create!(user: user, name: 'Toggle private feed', private: false)
    end
    travel_to(Time.zone.local(2026, 6, 11, 9, 0, 0)) do
      setup.update!(private: true)
    end

    assert UserActivity.exists?(user: user, subject: setup, verb: 'setup_made_private')
    items = timeline_items_for(user.reload)
    assert_not(items.any? { |i| i.verb == :setup_made_private })
  end

  private

  def flat_timeline_items_for(user, time_zone:)
    UserActivityTimeline.grouped_for(user, time_zone: time_zone).flat_map do |row|
      row.is_a?(UserActivityTimeline::Grouped) ? row.items : [row.item]
    end
  end

  def timeline_items_for(user)
    UserActivityTimeline.grouped_for(user).flat_map do |row|
      row.is_a?(UserActivityTimeline::Grouped) ? row.items : [row.item]
    end
  end

  def timeline_row_keys(rows)
    rows.map do |row|
      verb = row.is_a?(UserActivityTimeline::Grouped) ? row.verb : row.item.verb
      logged_at = row.is_a?(UserActivityTimeline::Grouped) ? row.logged_at : row.item.logged_at
      [verb, logged_at]
    end
  end

  def possession_presenter_path(possession)
    PossessionPresenterService.map_to_presenters([possession]).first.show_path
  end
end
