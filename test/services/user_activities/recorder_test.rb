# frozen_string_literal: true

require 'test_helper'

class UserActivitiesRecorderTest < ActiveSupport::TestCase
  test 'sync_possession hides stale verb rows when possession state changes' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 3, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:diy_kit), prev_owned: true)
    end
    UserActivities::Recorder.sync_possession(possession)
    assert UserActivity.visible.exists?(user: user, subject: possession, verb: 'added_to_previous')

    possession.update!(prev_owned: false, moved_to_previous_at: nil)
    UserActivities::Recorder.sync_possession(possession.reload)

    assert UserActivity.visible.exists?(user: user, subject: possession, verb: 'added_to_collection')
    stale = UserActivity.find_by!(user: user, subject: possession, verb: 'added_to_previous')
    assert stale.hidden_at.present?
  end

  test 'sync_possession is idempotent for same possession state' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 1, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:one), prev_owned: false)
    end

    UserActivities::Recorder.sync_possession(possession)
    count_after_first = UserActivity.where(user: user, subject: possession).count

    UserActivities::Recorder.sync_possession(possession.reload)
    assert_equal count_after_first, UserActivity.where(user: user, subject: possession).count
  end

  test 'hide_possession_activities! sets hidden_at on all possession activities' do
    user = users(:without_anything)
    possession = travel_to(Time.zone.local(2026, 3, 2, 10, 0, 0)) do
      Possession.create!(user: user, product: products(:two), prev_owned: false)
    end
    possession.update!(prev_owned: true)
    UserActivities::Recorder.sync_possession(possession.reload)

    acts = UserActivity.where(user: user, subject: possession)
    assert acts.any?
    assert(acts.all? { |a| a.hidden_at.nil? })

    UserActivities::Recorder.hide_possession_activities!(possession)
    assert(UserActivity.where(user: user, subject: possession).all? { |a| a.reload.hidden_at.present? })
  end

  test 'setup_made_public creates a distinct activity row' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 4, 1, 9, 0, 0)) do
      Setup.create!(user: user, name: 'Recorder private setup', private: true)
    end
    assert UserActivity.exists?(user: user, subject: setup, verb: 'setup_created')

    assert_difference(-> { UserActivity.where(user: user, subject: setup).count }, 1) do
      travel_to(Time.zone.local(2026, 4, 1, 10, 0, 0)) do
        setup.update!(private: false)
      end
    end

    verbs = UserActivity.where(user: user, subject: setup).order(:occurred_at).pluck(:verb)
    assert_includes verbs, 'setup_created'
    assert_includes verbs, 'setup_made_public'
  end

  test 'setup_made_private creates a distinct activity row when setup becomes private' do
    user = users(:without_anything)
    setup = travel_to(Time.zone.local(2026, 4, 2, 9, 0, 0)) do
      Setup.create!(user: user, name: 'Recorder public then private', private: false)
    end

    assert_difference(-> { UserActivity.where(user: user, subject: setup, verb: 'setup_made_private').count }, 1) do
      travel_to(Time.zone.local(2026, 4, 2, 10, 0, 0)) do
        setup.update!(private: true)
      end
    end
  end

  test 'event_attendance_cancelled creates activity with event subject' do
    user = users(:without_anything)
    event = travel_to(Time.zone.local(2026, 5, 1, 12, 0, 0)) do
      Event.create!(
        name: 'Cancelled event',
        address: 'a',
        url: 'https://example.test/cancel-rec',
        country_code: 'DE',
        start_date: Date.new(2026, 6, 1),
        end_date: Date.new(2026, 6, 2)
      )
    end

    assert_difference(-> { UserActivity.where(user: user, verb: 'event_attendance_cancelled').count }, 1) do
      UserActivities::Recorder.event_attendance_cancelled(user: user, event: event)
    end

    act = UserActivity.find_by!(user: user, subject: event, verb: 'event_attendance_cancelled')
    assert_equal 'Cancelled event', act.metadata['display_name']
  end

  test 'custom_product_created skips when user missing' do
    cp = CustomProduct.new(name: 'orphan')

    assert_no_difference(-> { UserActivity.count }) do
      UserActivities::Recorder.custom_product_created(cp)
    end
  end
end
