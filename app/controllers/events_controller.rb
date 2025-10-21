class EventsController < ApplicationController
  def index
    all_events = Event.where(end_date: Time.zone.today..).or(Event.where(start_date: Time.zone.today.., end_date: nil))
    @events = all_events
    @events = all_events.where(country_code: params[:country]) if params[:country].present?
    @years = @events.order(:start_date)
                    .group_by { |e| e.start_date.year }
                    .transform_values do |events_in_year|
                      events_in_year.group_by { |e| e.start_date.month }
                    end
    @country_codes = all_events.map(&:country_code).uniq.sort
    @page_title = 'Hi-Fi Events &amp; Shows'
    @meta_desc = 'Find all upcoming hi-fi events and shows on HiFi Log,
a user-driven database for hi-fi products, brands and more.'
  end
end
