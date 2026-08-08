# frozen_string_literal: true

# Shared view-model building for the grouped event lists rendered by both the
# public events pages (EventsController) and the dashboard "my events" pages
# (Dashboard::EventsController).
#
# +load_events+ populates @events, @event_attendee_counts and @years from a base
# relation, applying the optional +?country=+ filter and batching attendee counts
# for the list cards. Callers pass +country_codes+ for the filter dropdown, since
# its scope differs between surfaces (all events vs. only the current user's).
module EventListing
  extend ActiveSupport::Concern

  private

  def load_events(base_relation, order:, country_codes:)
    scope = base_relation
    scope = scope.where(country_code: params[:country]) if params[:country].present?

    @events = scope.order(start_date: order).to_a
    @event_attendee_counts = EventAttendee.counts_for(@events.map(&:id))
    @years = group_events_by_year_and_month(@events)
    @country_codes = country_codes
  end

  def group_events_by_year_and_month(events)
    events.group_by { |event| event.start_date.year }
          .transform_values do |events_in_year|
            events_in_year.group_by { |event| event.start_date.month }
          end
  end
end
