class EventsController < ApplicationController
  def index
    @all_upcoming_events_count = Event.cached_upcoming_count
    @all_past_events_count = Event.cached_past_count

    get_events(base_relation: Event.upcoming, order: :asc)

    @page_title = 'Hi-Fi Events &amp; Shows'
    @meta_desc = 'Find all upcoming hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :upcoming
    @after_create_redirect = :events
    @after_destroy_redirect = :events
    @canonical_url = events_url
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

    @page_title = 'Past Hi-Fi Events &amp; Shows'
    @meta_desc = 'Find all previous hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :past
    @after_create_redirect = :past_events
    @after_destroy_redirect = :past_events
    @canonical_url = past_events_url

    render 'index'
  end

  private

  def get_events(base_relation:, order: :asc)
    # 1. Apply country filter if present
    scope = base_relation
    scope = scope.where(country_code: params[:country]) if params[:country].present?

    # 2. Load records. By including event_attendees, we solve N+1 issues
    @events = scope.includes(event_attendees: :user).order(start_date: order)

    # 3. Grouping - Works for "All" (Upcoming) and "Yearly" (Past)
    @years = @events.group_by { |e| e.start_date.year }.transform_values do |events_in_year|
      events_in_year.group_by { |e| e.start_date.month }
    end

    # 4. Global list of country codes for the filter dropdown
    @country_codes = Rails.cache.fetch('events/country_codes') do
      Event.distinct.pluck(:country_code).compact.sort
    end

    # 5. Optimized Bookmarks (Uses the already-loaded @events IDs)
    @event_bookmarks = if user_signed_in?
                         current_user.bookmarks
                                     .where(item_type: 'Event', item_id: @events.map(&:id))
                                     .index_by(&:item_id)
                       else
                         {}
                       end
  end
end
