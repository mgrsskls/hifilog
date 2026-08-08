# frozen_string_literal: true

class Dashboard::EventsController < ApplicationController
  include EventListing

  before_action :authenticate_user!
  before_action :set_menu

  def index
    page_title(Event.model_name.human.pluralize)
    @active_dashboard_menu = :events
    @active_events = :upcoming

    user_events = current_user.events

    all_events = user_events.upcoming
    load_events(all_events, order: :asc, country_codes: user_event_country_codes(all_events))
    @all_upcoming_events_count = all_events.size
    today = Time.zone.today
    @all_past_events_count = user_events
                             .where(end_date: ..today)
                             .or(Event.where(start_date: ..today, end_date: nil))
                             .size
    @empty_state_message = I18n.t('event_attendee.empty_states.user.upcoming', path: events_path)
  end

  def past
    page_title("Past #{Event.model_name.human.pluralize}")
    @active_dashboard_menu = :events
    @active_events = :past

    today = Time.zone.today

    user_events = current_user.events

    all_events = user_events.where(end_date: ..today)
                            .or(Event.where(start_date: ..today, end_date: nil))
    load_events(all_events, order: :desc, country_codes: user_event_country_codes(all_events))
    @all_upcoming_events_count = user_events.upcoming.size
    @all_past_events_count = all_events.size
    @empty_state_message = I18n.t('event_attendee.empty_states.user.past', path: past_events_path)

    render 'index'
  end

  private

  def set_menu
    @active_menu = :dashboard
  end

  # Filter dropdown scoped to the countries the user actually has events in,
  # independent of the current +?country=+ filter.
  def user_event_country_codes(all_events)
    all_events.map(&:country_code).uniq.sort
  end
end
