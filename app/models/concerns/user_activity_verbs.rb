# frozen_string_literal: true

# Shared verb constants and i18n key helpers for the activity feed.
module UserActivityVerbs
  ICON_VERBS = [
    :added_to_collection,
    :added_to_previous,
    :moved_to_previous,
    :event_attendance,
    :event_attendance_cancelled,
    :setup_created,
    :setup_made_public,
    :setup_product_added,
    :setup_product_removed,
    :custom_product_created,
    :possession_image_uploaded,
    :followed_by_user,
    :brand_product_listed,
    :brand_variant_listed
  ].freeze

  SETUP_PRODUCT_VERBS = [:setup_product_added, :setup_product_removed].freeze

  # Catalog entries from a followed brand. These are not UserActivity verbs -- no row is ever
  # written for them -- but the feed renders them through the same Item struct and helpers.
  #
  # "listed", not "added" or "new": the event is that a contributor entered the thing into
  # HiFi Log, which says nothing about when the brand released it -- a decades-old amplifier is
  # listed today just as often as this year's. A brand announcing its own product would be a
  # different event and needs its own verb.
  BRAND_VERBS = [:brand_product_listed, :brand_variant_listed].freeze

  module_function

  def icon_verb?(verb)
    ICON_VERBS.include?(verb&.to_sym)
  end

  def setup_product_verb?(verb)
    SETUP_PRODUCT_VERBS.include?(verb&.to_sym)
  end

  def brand_verb?(verb)
    BRAND_VERBS.include?(verb&.to_sym)
  end

  def title_i18n_key(verb, event_past: nil)
    verb = verb.to_sym
    case verb
    when :event_attendance
      if event_past
        'user_activity.title.event_attendance_past_html'
      else
        'user_activity.title.event_attendance_upcoming_html'
      end
    when :event_attendance_cancelled
      'user_activity.title.event_attendance_cancelled_html'
    when :setup_product_added
      'user_activity.title.setup_product_added_html'
    when :setup_product_removed
      'user_activity.title.setup_product_removed_html'
    else
      "user_activity.title.#{verb}_html"
    end
  end

  def grouped_summary_i18n_key(verb, event_past: nil)
    verb = verb.to_sym
    case verb
    when :event_attendance
      if event_past
        'user_activity.grouped.summary_event_attendance_past_html'
      else
        'user_activity.grouped.summary_event_attendance_upcoming_html'
      end
    when :event_attendance_cancelled
      'user_activity.grouped.summary_event_attendance_cancelled_html'
    else
      "user_activity.grouped.summary_#{verb}_html"
    end
  end
end
