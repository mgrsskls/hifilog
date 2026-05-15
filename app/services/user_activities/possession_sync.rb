# frozen_string_literal: true

# Derives which possession-backed activity rows should exist for +possession+, mirroring
# UserActivityTimeline possession rules (same thresholds and coalescing).
class UserActivities::PossessionSync
  CUSTOM_PRODUCT_POSSESSION_MERGE_WINDOW = 2.seconds

  # Verbs owned by +sync_possession+; stale rows outside the current expected set are hidden.
  POSSESSION_VERBS = %w[added_to_collection added_to_previous moved_to_previous].freeze

  class << self
    def expected_rows(possession)
      rows = []
      possession_activities(possession) do |verb, logged_at, meta|
        rows << { verb:, occurred_at: logged_at, metadata: meta || {} }
      end
      rows.reject { |r| r[:occurred_at].blank? }
    end

    private

    def possession_activities(possession)
      if treat_as_moved_to_previous?(possession)
        if moved_to_previous_timestamp(possession).present? && !suppress_collection_add_for_custom_product?(possession)
          yield(:added_to_collection, possession_created_or_user_logged_at(possession), possession_meta(possession))
        end
        yield(:moved_to_previous, move_from_collection_logged_at(possession), possession_meta(possession))
        return
      end

      if possession.prev_owned?
        yield(:added_to_previous, added_to_previous_activity_logged_at(possession), possession_meta(possession))
        return
      end

      return if suppress_collection_add_for_custom_product?(possession)

      yield(:added_to_collection, possession_created_or_user_logged_at(possession), possession_meta(possession))
    end

    def possession_meta(possession)
      {
        'period_from' => possession.period_from&.iso8601,
        'period_to' => possession.period_to&.iso8601,
        'possession_created_at' => possession.created_at&.iso8601
      }.compact
    end

    def treat_as_moved_to_previous?(possession)
      moved_to_previous_timestamp(possession).present? ||
        (possession.prev_owned? && possession.period_to.present?)
    end

    def move_from_collection_logged_at(possession)
      ts = moved_to_previous_timestamp(possession)
      return ts if possession_system_logged_time?(ts)

      coalesce_possession_logged_at(possession, include_period_from: false, include_period_to: false)
    end

    def suppress_collection_add_for_custom_product?(possession)
      return false unless possession.custom_product_id?

      cp = possession.custom_product
      return false unless cp
      return false if possession.created_at.blank?
      return false unless possession_system_logged_time?(possession.created_at)

      (possession.created_at - cp.created_at).abs <= CUSTOM_PRODUCT_POSSESSION_MERGE_WINDOW
    end

    def possession_created_or_user_logged_at(possession)
      return possession.created_at if possession_system_logged_time?(possession.created_at)

      user_ts = possession.user&.created_at
      return user_ts if possession_system_logged_time?(user_ts)

      nil
    end

    def coalesce_possession_logged_at(possession, include_period_from: true, include_period_to: true)
      return possession.created_at if possession_system_logged_time?(possession.created_at)

      ts = moved_to_previous_timestamp(possession)
      return ts if possession_system_logged_time?(ts)

      user_ts = possession.user&.created_at
      usable_user_ts = possession_system_logged_time?(user_ts) ? user_ts : nil

      (include_period_from ? possession.period_from.presence : nil) ||
        (include_period_to ? possession.period_to.presence : nil) ||
        usable_user_ts
    end

    def added_to_previous_activity_logged_at(possession)
      possession_created_or_user_logged_at(possession)
    end

    def possession_system_logged_time?(time)
      return false if time.blank?

      time.to_time.utc >= Time.utc(1970, 1, 2)
    end

    # Column is from +db/migrate/*_add_moved_to_previous_at_to_possessions.rb+; +try+ avoids NoMethodError if migrate
    # has not been run yet (read-only paths such as backfill).
    def moved_to_previous_timestamp(possession)
      possession.try(:moved_to_previous_at)
    end
  end
end
