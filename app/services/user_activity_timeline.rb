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
# - Event attendance copy (+Item#event_past+): "Attended …" only after the event has ended (today in the
#   feed time zone is later than +end_date+, or +start_date+ when there is no end date); until then "Will attend …".
# - Setups: only rows for setups that are currently public, or deleted setups with +metadata+ indicating
#   they were public when destroyed (+private+ is false in merged metadata).
# - +setup_product_added+ / +setup_product_removed+: subject is +Setup+; product label snapshots and stable
#   foreign keys (+possession_id+, +product_id+, +product_variant_id+, +custom_product_id+) live in +metadata+;
#   URLs are derived at render time (see +SubjectLookup#setup_product_activity_product_url+).
# - Rows from when the setup was private are omitted (+metadata+ +private+ at write time, or
#   +recorded_while_setup_private+ which +before_destroy+ metadata snapshots do not overwrite).
# - +possession_image_uploaded+ groups only within the same possession (+cluster_key+ includes +possession_id+);
#   each upload is a separate row (dedupe includes +image_attachment_id+). Thumbnails render on the feed.
# - +setup_made_private+, +possession_image_deleted+, and profile image verbs (+avatar_*+, +decorative_image_*+)
#   are stored but never rendered on the feed.
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
    :possession_id,
    :gallery_image,
    :actor_user_id,
    :actor_user_name,
    :actor_profile_path,
    :actor_user,
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

  # +rows+ are the grouped rows for the requested page; +activities+ is the
  # Kaminari-paginated relation backing them (for the paginate view helper).
  PaginatedFeed = Struct.new(:rows, :activities, keyword_init: true)

  def self.grouped_for(user, time_zone: Time.zone, limit: nil, public_profile_feed: false)
    new(user, time_zone:, limit:, public_profile_feed:).grouped_rows
  end

  def self.grouped_for_following(viewer, time_zone: Time.zone, limit: nil)
    new_for_following(viewer, time_zone:, limit:).grouped_rows
  end

  def self.paginated_for_following(viewer, time_zone: Time.zone, page: nil, per: 50)
    new_for_following(viewer, time_zone:).paginated_rows(page:, per:)
  end

  def self.new_for_following(viewer, time_zone: Time.zone, limit: nil)
    followed_ids = viewer.followed_users.visible_in_follow_feed.pluck(:id)
    new(viewer, time_zone:, limit:, following_user_ids: [viewer.id] + followed_ids)
  end
  private_class_method :new_for_following

  # +following_user_ids+ marks a following feed: it lists whose activities to
  # include (viewer first) and switches on actor display for every row.
  def initialize(user, time_zone: Time.zone, limit: nil, following_user_ids: nil, public_profile_feed: false)
    @user = user
    @viewer_id = user.id
    @user_ids = following_user_ids || [user.id]
    @multi_user = @user_ids.size > 1
    @show_actor = following_user_ids.present?
    @public_profile_feed = public_profile_feed
    @time_zone = time_zone
    @limit = limit
  end

  def grouped_rows
    rows = build_grouped_rows(flat_items(activities_for_timeline))
    @limit ? rows.first(@limit) : rows
  end

  # Paginates activities at the database level instead of loading the whole
  # timeline. Grouping and deduping apply per page, so a cluster that spans a
  # page boundary renders as separate (possibly ungrouped) rows on each page.
  def paginated_rows(page:, per:)
    activities = timeline_activities_scope.page(page).per(per)
    activities = timeline_activities_scope.page(1).per(per) if activities.out_of_range?

    loaded = activities.to_a
    preload_timeline_subjects!(loaded)
    PaginatedFeed.new(rows: build_grouped_rows(flat_items(loaded)), activities:)
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
    scope = timeline_activities_scope
    return scope unless @limit

    capped = scope.limit(activities_fetch_limit)
    capped_activities = capped.to_a
    return capped if capped_activities.size < activities_fetch_limit

    scope
  end

  def timeline_activities_scope
    feed_scope = @public_profile_feed ? UserActivity.for_public_profile_feed : UserActivity.for_feed
    scope =
      UserActivity.where(user_id: @user_ids)
                  .merge(feed_scope)
                  .chronological
                  .includes(:subject, :user)
    scope = following_feed_visibility(scope) if @multi_user
    scope
  end

  # Two rules for the following feed; the viewer's own rows are unrestricted:
  # - Who follows a user is only their own business: never expose
  #   followed_by_user rows belonging to other users.
  # - A followed user's activities only appear from the moment the viewer
  #   followed them; their earlier history stays off the feed.
  def following_feed_visibility(scope)
    scope = scope.where.not(verb: 'followed_by_user').or(scope.where(user_id: @viewer_id))
    scope.where(<<~SQL.squish, viewer_id: @viewer_id)
      user_activities.user_id = :viewer_id OR EXISTS (
        SELECT 1 FROM user_follows
        WHERE user_follows.follower_id = :viewer_id
          AND user_follows.followed_id = user_activities.user_id
          AND user_activities.occurred_at >= user_follows.created_at
      )
    SQL
  end

  def activities_fetch_limit
    (@limit * GROUP_THRESHOLD * 3) + GROUP_THRESHOLD
  end

  def preload_timeline_subjects!(activities)
    attendees = activities.filter_map { |a| a.subject if a.subject_type == 'EventAttendee' }
    custom_products = activities.filter_map { |a| a.subject if a.subject_type == 'CustomProduct' }
    preload_association(attendees, :event)
    preload_association(custom_products, :user)
    user_follows = activities.filter_map { |a| a.subject if a.subject_type == 'UserFollow' }
    preload_association(user_follows, :follower)
    return unless @show_actor

    preload_association(activities.filter_map(&:user).uniq, { avatar_attachment: :blob })
    preload_association(user_follows.filter_map(&:follower).uniq, { avatar_attachment: :blob })
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
    possession_scope =
      if item.verb == :possession_image_uploaded
        item.possession_id || 0
      else
        :_
      end
    user_scope = @multi_user ? (item.actor_user_id || 0) : :_
    [day, cluster_verb, suffix, setup_scope, possession_scope, user_scope]
  end

  def flat_items(activities)
    @lookups_by_user_id = {}
    activities_by_user_id = activities.group_by(&:user_id)

    pairs =
      activities.filter_map do |a|
        activity_user = a.user
        made_public_setup_ids = made_public_setup_ids_for_suppression(activity_user)
        next if suppress_setup_created_after_private_then_public?(a, made_public_setup_ids)

        @user = activity_user
        @lookup = lookup_for(activity_user, activities_by_user_id[activity_user.id])

        item = activity_to_item(a)
        next unless item
        next if item.logged_at.blank?

        item = item_with_actor(item, activity_actor_user(a, activity_user)) if @show_actor

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
    when 'possession_image_uploaded'
      attachment_id = activity.metadata&.[]('image_attachment_id')
      return nil if attachment_id.blank?

      [activity.verb, activity.subject_type, activity.subject_id, attachment_id.to_s]
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

  def activity_actor_user(activity, activity_user)
    return activity_user unless activity.verb == 'followed_by_user'

    follow = activity.subject
    follow.is_a?(UserFollow) ? follow.follower : activity_user
  end

  def lookup_for(user, user_activities)
    @lookups_by_user_id[user.id] ||= SubjectLookup.new(user:, activities: user_activities)
  end

  def item_with_actor(item, user)
    Item.new(
      **item.to_h,
      actor_user_id: user.id,
      actor_user_name: user.user_name,
      actor_profile_path: user.profile_path,
      actor_user: user
    )
  end

  def made_public_setup_ids_for_suppression(user)
    made_public_setup_ids_by_user_id.fetch(user.id) { Set.new }
  end

  # One query for all feed users instead of one per user.
  def made_public_setup_ids_by_user_id
    @made_public_setup_ids_by_user_id ||=
      UserActivity.where(user_id: @user_ids, verb: 'setup_made_public')
                  .includes(:subject)
                  .to_a
                  .group_by(&:user_id)
                  .transform_values { |activities| setup_subject_ids_with_verb(activities, 'setup_made_public') }
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
