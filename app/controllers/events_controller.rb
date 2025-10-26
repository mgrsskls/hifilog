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
    @after_destroy_redirect = :events
    @canonical_url = events_url
  end

  def past
    all_events = Event.where(end_date: ..Time.zone.yesterday).or(Event.where(start_date: ..Time.zone.yesterday,
                                                                             end_date: nil))
    get_events(all_events:, order: :desc)
    @all_upcoming_events_count = Event.where(end_date: Time.zone.today..)
                                      .or(Event.where(start_date: Time.zone.today.., end_date: nil))
                                      .size
    @all_past_events_count = all_events.size
    @page_title = 'Past Hi-Fi Events &amp; Shows'
    @meta_desc = 'Find all previous hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
    @active_events = :past
    @after_destroy_redirect = :past_events
    @canonical_url = past_events_url

    render 'index'
  end

  private

  def get_events(all_events: [], order: :asc)
    @events = all_events.includes(event_attendees: [:user])
    @events = all_events.where(country_code: params[:country]) if params[:country].present?
    @years = @events.order(start_date: order)
                    .group_by { |e| e.start_date.year }
                    .transform_values do |events_in_year|
                      events_in_year.group_by { |e| e.start_date.month }
                    end
    @country_codes = all_events.map(&:country_code).uniq.sort
  end
end
