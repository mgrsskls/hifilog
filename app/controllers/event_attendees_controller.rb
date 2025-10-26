class EventAttendeesController < ApplicationController
  before_action :authenticate_user!

  def create
    @event = Event.find(params[:event_id]) if params[:event_id].present?

    @event_attendee = current_user.event_attendees.new(
      event: @event
    )

    flash[:alert] = I18n.t(:generic_error_message) unless @event_attendee.save

    anchor = "event-#{@event.id}"

    case params[:redirect]
    when 'dashboard_bookmarks' then redirect_to dashboard_bookmarks_path(anchor:)
    when 'dashboard_events' then redirect_to dashboard_events_path(anchor:)
    when 'dashboard_past_events' then redirect_to dashboard_past_events_path(anchor:)
    when 'past_events' then redirect_to past_events_path(anchor:)
    else redirect_to events_path(anchor:)
    end
  end

  def destroy
    event_attendee = current_user.event_attendees.find(params[:id])
    event = event_attendee.event

    if event_attendee&.destroy
      flash[:notice] = I18n.t(
        "event_attendee.messages.destroyed.#{params[:past] == 'true' ? 'past' : 'upcoming'}",
        name: event.name
      )
    end

    case params[:redirect]
    when 'dashboard_bookmarks' then redirect_to dashboard_bookmarks_path
    when 'dashboard_events' then redirect_to dashboard_events_path
    when 'dashboard_past_events' then redirect_to dashboard_past_events_path
    when 'past_events' then redirect_to past_events_path
    else redirect_to events_path
    end
  end
end
