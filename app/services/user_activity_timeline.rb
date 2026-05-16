# frozen_string_literal: true

# Builds the public profile activity feed from persisted +UserActivity+ rows.
#
# Policy (aligned with product plan):
# - Subject dates (+period_from+ / event dates) are display context only, never used for ordering.
# - +GROUP_THRESHOLD+: same +cluster_key+ on **contiguous** items in feed order (newest first; same calendar day,
#   verb bucket, and +setup_scope+ from +cluster_key+) → one grouped card when count ≥ threshold. Any other
#   row between two same-key items starts a new run, so groups do not absorb non-adjacent same-day events
#   (+setup_product_added+ vs +setup_product_removed+ use different keys; +setup_created+ breaks a product run).
# - +setup_made_public+ uses the same clustering bucket as +setup_created+ (+cluster_key+ maps the verb).
# - +setup_created+ is omitted from the feed when the setup was created private (+metadata+ +private+) and a
#   +setup_made_public+ row exists for the same setup, so “draft then publish” shows one line (+setup_made_public+).
# - Event attendance copy (+Item#event_past+): "Attended …" only when the RSVP was created on or after the
#   calendar start of the event; earlier RSVPs stay on "Will attend …" even after the event has ended.
# - Setups: only rows for setups that are currently public, or deleted setups with +metadata+ indicating
#   they were public when destroyed (+private+ is false in merged metadata).
# - +setup_product_added+ / +setup_product_removed+: subject is +Setup+; product label snapshots and stable
#   foreign keys (+possession_id+, +product_id+, +product_variant_id+, +custom_product_id+) live in +metadata+;
#   URLs are derived at render time (see +SubjectLookup#setup_product_activity_product_url+).
# - Rows from when the setup was private are omitted (+metadata+ +private+ at write time, or
#   +recorded_while_setup_private+ which +before_destroy+ metadata snapshots do not overwrite).
# - +setup_made_private+, possession/profile image upload/delete verbs (+possession_image_*+, +avatar_*+,
#   +decorative_image_*+) are stored but never rendered on the feed.
# - Only +setup_made_public+ / +setup_created+ setup lines appear when the setup is currently public or was
#   public when destroyed.
# - Same +logged_at+ (e.g. backfill using +setup.created_at+ for both): +setup_product_added+ /
#   +setup_product_removed+ sort above +setup_created+ / +setup_made_public+ so the feed (newest first)
#   shows membership changes before the “created setup” line for that instant.
# - Consecutive rows with the same dedupe key (+verb+ + subject identity, and for +setup_product_*+ the
#   possession in metadata) collapse to the newest only (feed order is newest first).
class UserActivityTimeline
  include Rails.application.routes.url_helpers
  include ItemBuilders

  GROUP_THRESHOLD = 3

  Item = Struct.new(
    :verb,
    :logged_at,
    :display_name,
    :url,
    :period_from,
    :period_to,
    :event_start_date,
    :event_end_date,
    :event_past,
    :possession_created_at,
    :setup_name,
    :setup_url,
    :setup_id,
    keyword_init: true
  ) do
    def event_upcoming?
      verb == :event_attendance && event_past == false
    end
  end

  Grouped = Struct.new(:verb, :logged_at, :items, :event_past, keyword_init: true) do
    def event_upcoming?
      verb == :event_attendance && event_past == false
    end
  end
  Single = Struct.new(:item, keyword_init: true) do
    delegate :event_upcoming?, to: :item
  end

  def self.grouped_for(user, time_zone: Time.zone, limit: nil)
    new(user, time_zone:, limit:).grouped_rows
  end

  def initialize(user, time_zone: Time.zone, limit: nil)
    @user = user
    @time_zone = time_zone
    @limit = limit
  end

  def grouped_rows
    rows = build_grouped_rows(flat_items)
    @limit ? rows.first(@limit) : rows
  end

  private

  def build_grouped_rows(flat)
    rows = []
    contiguous_cluster_key_runs(flat).each do |items|
      append_grouped_or_singles!(rows, items)
    end
    rows.sort_by! { |r| timeline_row_sort_tuple(r) }
  end

  def activities_for_timeline
    activities = timeline_activities.to_a
    preload_timeline_subjects!(activities)
    activities
  end

  def timeline_activities
    scope = @user.user_activities.visible.for_feed.chronological.includes(:subject)
    return scope unless @limit

    capped = scope.limit(activities_fetch_limit)
    capped_activities = capped.to_a
    return capped if capped_activities.size < activities_fetch_limit

    scope
  end

  def activities_fetch_limit
    (@limit * GROUP_THRESHOLD * 3) + GROUP_THRESHOLD
  end

  def preload_timeline_subjects!(activities)
    attendees = activities.filter_map { |a| a.subject if a.subject_type == 'EventAttendee' }
    custom_products = activities.filter_map { |a| a.subject if a.subject_type == 'CustomProduct' }
    preload_association(attendees, :event)
    preload_association(custom_products, :user)
  end

  def preload_association(records, *associations)
    records = Array(records).compact
    return if records.empty?

    ActiveRecord::Associations::Preloader.new(records:, associations:).call
  end

  def append_grouped_or_singles!(rows, items)
    items.sort_by!(&:logged_at).reverse!
    if items.size >= GROUP_THRESHOLD
      rows << Grouped.new(
        verb: items.first.verb,
        logged_at: items.map(&:logged_at).max,
        items:,
        event_past: grouped_row_event_past(items)
      )
    else
      items.each { |i| rows << Single.new(item: i) }
    end
  end

  # +flat+ is newest-first; a run is a maximal consecutive slice sharing the same +cluster_key+.
  def contiguous_cluster_key_runs(flat)
    runs = []
    flat.each do |item|
      key = cluster_key(item)
      if runs.empty? || cluster_key(runs.last.first) != key
        runs << [item]
      else
        runs.last << item
      end
    end
    runs
  end

  def timeline_row_sort_tuple(row)
    logged = (row.is_a?(Grouped) ? row.logged_at : row.item.logged_at).to_f
    tie = timeline_row_tie_break_rank(row)
    [-logged, tie]
  end

  # Smaller tie sorts first alongside +-logged+ (newest first). At the same instant, setup membership lines are
  # newer than setup creation, so +setup_product_*+ ranks ahead of +setup_created+ / +setup_made_public+.
  def timeline_row_tie_break_rank(row)
    verb = row.is_a?(Grouped) ? row.verb : row.item.verb
    case verb
    when :setup_product_added, :setup_product_removed
      0
    when :setup_created, :setup_made_public
      1
    else
      2
    end
  end

  def grouped_row_event_past(items)
    return nil unless items.first.verb == :event_attendance

    items.first.event_past
  end

  def cluster_key(item)
    day = item.logged_at.in_time_zone(@time_zone).to_date
    cluster_verb =
      case item.verb
      when :setup_made_public
        :setup_created
      else
        item.verb
      end
    suffix =
      case cluster_verb
      when :event_attendance
        item.event_past ? :past : :upcoming
      else
        :_
      end
    setup_scope =
      case item.verb
      when :setup_product_added, :setup_product_removed, :setup_created, :setup_made_public
        item.setup_id || 0
      else
        :_
      end
    [day, cluster_verb, suffix, setup_scope]
  end

  def flat_items
    activities = activities_for_timeline
    @lookup = SubjectLookup.new(user: @user, activities:)
    made_public_setup_ids = made_public_setup_ids_for_suppression

    pairs =
      activities.filter_map do |a|
        next if suppress_setup_created_after_private_then_public?(a, made_public_setup_ids)

        item = activity_to_item(a)
        next unless item
        next if item.logged_at.blank?

        [a, item]
      end

    pairs.sort_by! { |(a, i)| [-i.logged_at.to_f, -a.id] }
    dedupe_consecutive_same_feed_activity(pairs).map(&:last)
  end

  # Newest-first list: drop an item when it immediately follows another with the same dedupe key
  # (+verb+ + polymorphic subject; +setup_product_*+ also includes +possession_id+ from metadata).
  def dedupe_consecutive_same_feed_activity(pairs)
    pairs.each_with_object([]) do |(activity, item), acc|
      key = activity_feed_dedupe_key(activity)
      if key.nil?
        acc << [activity, item]
        next
      end

      prev = acc.last
      prev_key = prev ? activity_feed_dedupe_key(prev.first) : nil
      acc << [activity, item] unless prev_key == key
    end
  end

  def activity_feed_dedupe_key(activity)
    return nil if activity.subject_id.blank?

    case activity.verb
    when 'setup_product_added', 'setup_product_removed'
      pid = activity.metadata&.[]('possession_id')
      return nil if pid.blank?

      [activity.verb, activity.subject_type, activity.subject_id, pid.to_i]
    else
      [activity.verb, activity.subject_type, activity.subject_id]
    end
  end

  def suppress_setup_created_after_private_then_public?(activity, made_public_setup_ids)
    return false unless activity.verb == 'setup_created'
    return false unless activity_created_as_private_setup?(activity.metadata)

    id = setup_activity_subject_id(activity)
    id.present? && made_public_setup_ids.include?(id)
  end

  def activity_created_as_private_setup?(metadata)
    ActiveModel::Type::Boolean.new.cast((metadata || {})['private'])
  end

  def made_public_setup_ids_for_suppression
    @made_public_setup_ids_for_suppression ||= begin
      activities = @user.user_activities.where(verb: 'setup_made_public').includes(:subject).to_a
      setup_subject_ids_with_verb(activities, 'setup_made_public')
    end
  end

  def setup_subject_ids_with_verb(activities, verb)
    activities.each_with_object(Set.new) do |a, set|
      next unless a.verb == verb

      id = setup_activity_subject_id(a)
      set.add(id) if id.present?
    end
  end

  def setup_activity_subject_id(activity)
    setup = activity.subject
    return setup.id if setup.is_a?(Setup)

    meta = activity.metadata || {}
    sid = meta['setup_id'].presence&.to_i
    sid&.positive? ? sid : nil
  end
end
