# frozen_string_literal: true

module UserActivityTimeline::ItemBuilders::EventItems
  private

  def event_attendance_activity_item(activity)
    attendee = activity.subject
    return nil unless attendee.is_a?(EventAttendee)

    event = attendee.event
    return nil unless event

    meta = activity.metadata || {}
    UserActivityTimeline::Item.new(
      verb: :event_attendance,
      logged_at: activity.occurred_at,
      display_name: event.name,
      url: meta['url'].presence || event_path(year: event.calendar_year, slug: event.friendly_id),
      period_from: nil,
      period_to: nil,
      event_start_date: event.start_date,
      event_end_date: event.end_date,
      event_past: event_attendance_past?(event),
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )
  end

  def event_cancelled_activity_item(activity)
    event = activity.subject
    meta = activity.metadata || {}
    display_name = event&.name.presence || meta['display_name'].presence || '—'
    url =
      if event
        event_path(year: event.calendar_year, slug: event.friendly_id)
      else
        meta['url'].presence || '#'
      end

    UserActivityTimeline::Item.new(
      verb: :event_attendance_cancelled,
      logged_at: activity.occurred_at,
      display_name:,
      url:,
      period_from: nil,
      period_to: nil,
      event_start_date: parse_meta_date(meta['event_start_date']),
      event_end_date: parse_meta_date(meta['event_end_date']),
      event_past: nil,
      possession_created_at: nil,
      setup_name: nil,
      setup_url: nil,
      setup_id: nil
    )
  end

  def event_attendance_past?(event)
    today = Time.current.in_time_zone(@time_zone).to_date
    last_day = event.end_date.presence || event.start_date
    return false if last_day.blank?

    today > last_day
  end
end
