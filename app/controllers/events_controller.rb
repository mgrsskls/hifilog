# frozen_string_literal: true

class EventsController < ApplicationController
  include EventListing
  include FriendlyFinder

  before_action :find_event, only: :show

  def index
    @all_upcoming_events_count = Event.cached_upcoming_count
    @all_past_events_count = Event.cached_past_count

    load_events(Event.upcoming, order: :asc, country_codes: all_event_country_codes)

    page_title('Hi-Fi Events &amp; Shows')
    @meta_desc = 'Find all upcoming hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :upcoming
    @canonical_url = events_url
    set_events_robots_meta
  end

  def show
    @bookmark = current_user.bookmarks.find_by(item_id: @event.id, item_type: 'Event') if user_signed_in?

    page_title(@event.name)
    @meta_desc = "#{@event.name} — hi-fi event on HiFi Log, a user-driven database for hi-fi products, brands and more."
    @canonical_url = event_url(year: @event.calendar_year, slug: @event.friendly_id)
  end

  def past
    @all_upcoming_events_count = Event.cached_upcoming_count
    @all_past_events_count = Event.cached_past_count

    # Past: Filter by Year (Defaulting to the most recent year with events)
    @available_years = Event.available_past_years
    @selected_year = params[:year].presence || @available_years.first

    # Only fetch the subset for the chosen year
    yearly_relation = Event.past.by_year(@selected_year)

    load_events(yearly_relation, order: :desc, country_codes: all_event_country_codes)

    page_title('Past Hi-Fi Events &amp; Shows')
    @meta_desc = 'Find all previous hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :past
    @canonical_url = past_events_url(year: @selected_year)

    set_events_robots_meta
    render 'index'
  end

  private

  def set_events_robots_meta
    return if params[:country].blank?

    @meta_robots = 'noindex, follow'
  end

  def find_event
    year = params[:year].to_i
    @event = find_resource(
      Event.includes(event_attendees: :user).where(calendar_year: year), :slug,
      path_helper: ->(event) { event_path(year: event.calendar_year, slug: event.friendly_id) }
    )
  end

  # Global list of country codes for the filter dropdown, cached across requests.
  def all_event_country_codes
    Rails.cache.fetch('events/country_codes') do
      Event.distinct.pluck(:country_code).compact.sort
    end
  end
end
