class EventsController < ApplicationController
  def index
    @all_upcoming_events_count = Event.cached_upcoming_count
    @all_past_events_count = Event.cached_past_count

    all_upcoming_events = Event.upcoming
    get_events(base_relation: all_upcoming_events, order: :asc)

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

    all_past_events = Event.past
    get_events(base_relation: all_past_events, order: :desc)

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
    scope = base_relation
    scope = scope.where(country_code: params[:country]) if params[:country].present?

    @events = scope.includes(event_attendees: :user)
                   .order(start_date: order)

    @country_codes = base_relation.distinct.pluck(:country_code).compact.sort

    @years = @events.group_by { |e| e.start_date.year }.transform_values do |events_in_year|
      events_in_year.group_by { |e| e.start_date.month }
    end

    @event_bookmarks = if user_signed_in?
                         current_user.bookmarks
                                     .where(item_type: 'Event', item_id: @events.map(&:id))
                                     .index_by(&:item_id)
                       else
                         {}
                       end
  end
end
