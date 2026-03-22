class EventsController < ApplicationController
  def index
    all_events = Event.where(end_date: Time.zone.today..).or(Event.where(start_date: Time.zone.today.., end_date: nil))
    get_events(all_events:, order: :asc)
    @all_upcoming_events_count = all_events.size
    @all_past_events_count = Event.where(end_date: ..Time.zone.yesterday)
                                  .or(Event.where(start_date: ..Time.zone.yesterday, end_date: nil))
                                  .size
    @page_title = 'Hi-Fi Events &amp; Shows'
    @meta_desc = 'Find all upcoming hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :upcoming
    @after_create_redirect = :events
    @after_destroy_redirect = :events
    @canonical_url = events_url
  end

  def past
    # Use scopes for readability
    all_past_events = Event.past

    # Optimization: Cache the counts to avoid heavy SQL hits every pageload
    @all_upcoming_events_count = Rails.cache.fetch('upcoming_events_count', expires_in: 1.hour) { Event.upcoming.size }
    @all_past_events_count = Rails.cache.fetch('past_events_count', expires_in: 1.hour) { all_past_events.size }

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
