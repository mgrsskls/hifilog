# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :find_event, only: :show

  def index
    @all_upcoming_events_count = Event.cached_upcoming_count
    @all_past_events_count = Event.cached_past_count

    get_events(base_relation: Event.upcoming, order: :asc)

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

    get_events(base_relation: yearly_relation, order: :desc)

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
    @event = Event.includes(event_attendees: :user)
                  .where(calendar_year: year)
                  .friendly
                  .find(params[:slug])

    canonical_path = URI.parse(event_path(year: @event.calendar_year, slug: @event.friendly_id)).path
    return if request.path == canonical_path

    redirect_to canonical_path, status: :moved_permanently and return
  end

  def get_events(base_relation:, order: :asc)
    # 1. Apply country filter if present
    scope = base_relation
    scope = scope.where(country_code: params[:country]) if params[:country].present?

    # 2. Load records; attendee counts are batched for list cards
    @events = scope.order(start_date: order).to_a
    ids = @events.map(&:id)
    @event_attendee_counts = EventAttendee.counts_for(ids)

    # 3. Grouping - Works for "All" (Upcoming) and "Yearly" (Past)
    @years = @events.group_by { |e| e.start_date.year }.transform_values do |events_in_year|
      events_in_year.group_by { |e| e.start_date.month }
    end

    # 4. Global list of country codes for the filter dropdown
    @country_codes = Rails.cache.fetch('events/country_codes') do
      Event.distinct.pluck(:country_code).compact.sort
    end
  end
end
