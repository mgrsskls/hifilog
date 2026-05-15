# frozen_string_literal: true

module UserActivityPeriodMeta
  def user_activity_item_meta_period(item)
    return unless user_activity_period_meta_eligible?(item)

    text = user_activity_period_meta(item)
    return if text.blank?

    tag.small(text)
  end

  private

  def user_activity_period_meta_eligible?(item)
    verb = item.verb&.to_sym
    activity_date = item.logged_at.in_time_zone(Time.zone).to_date

    case verb
    when :added_to_collection
      added_to_collection_period_meta_eligible?(item, activity_date)
    when :added_to_previous, :moved_to_previous
      item.period_to.present? && item.period_to.to_date != activity_date
    when :event_attendance_cancelled, :custom_product_created, :setup_created, :setup_made_public,
         :setup_product_added, :setup_product_removed, :event_attendance
      false
    else
      true
    end
  end

  def user_activity_period_meta(item)
    case item.verb&.to_sym
    when :added_to_previous
      return if item.period_to.blank?

      t('user_activity.meta.owned_until', to: format_date(item.period_to))
    else
      if item.period_from.present? && item.period_to.present?
        t(
          'user_activity.meta.owned_until',
          to: format_date(item.period_to)
        )
      elsif item.period_from.present?
        t('user_activity.meta.owned_since', date: format_date(item.period_from))
      end
    end
  end

  # Period line uses +period_from+ vs possession +created_at+ when present;
  # +logged_at+ may fall back to +user.created_at+.
  def added_to_collection_period_meta_eligible?(item, logged_activity_date)
    return false if item.period_from.blank?
    return true if item.period_to.present?

    period_day = item.period_from.to_date
    created = user_activity_usable_system_time(item.possession_created_at)
    period_day != if created
                    created.in_time_zone(Time.zone).to_date
                  else
                    logged_activity_date
                  end
  end

  # Aligns with +UserActivities::PossessionSync.possession_system_logged_time?+
  # (epoch / bad imports are not a real “created” day).
  def user_activity_usable_system_time(time)
    return nil if time.blank?
    return nil if time.to_time.utc < Time.utc(1970, 1, 2)

    time
  end
end
