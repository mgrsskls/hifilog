# frozen_string_literal: true

require 'test_helper'

class HomeHighlightsTest < ActiveSupport::TestCase
  test 'just_added mixes catalogue entries and brands, newest first' do
    entries = HomeHighlights.just_added

    assert_predicate entries, :any?
    assert_operator entries.length, :<=, HomeHighlights::JUST_ADDED_LIMIT
    assert(entries.all? { |entry| [:product, :brand].include?(entry.kind) })
    assert_equal entries.map(&:created_at).compact.sort.reverse, entries.map(&:created_at).compact
    assert(entries.all? { |entry| entry.title.present? && entry.path.present? })
  end

  test 'upcoming_events returns future events with their attendee counts' do
    events, counts = HomeHighlights.upcoming_events

    assert_predicate events, :any?
    assert(events.none? { |event| event.start_date < Time.zone.today })
    assert(counts.keys.all? { |id| events.map(&:id).include?(id) })
  end

  test 'photos only come from publicly indexable profiles' do
    photos = HomeHighlights.photos
    hidden_names = User.where.not(profile_visibility: :visible).pluck(:user_name)

    assert_kind_of Array, photos
    assert(photos.none? { |photo| hidden_names.include?(photo.user_name) })
  end
end
