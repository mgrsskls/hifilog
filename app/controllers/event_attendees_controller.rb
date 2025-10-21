class EventAttendeesController < ApplicationController
  before_action :authenticate_user!

  def create
    @event = Event.find(params[:event_id]) if params[:event_id].present?

    @event_attendee = current_user.event_attendees.new(
      event: @event
    )

    flash[:alert] = I18n.t(:generic_error_message) unless @event_attendee.save

    redirect_to events_path(anchor: "event-#{@event.id}")
  end

  def destroy
    event_attendee = current_user.event_attendees.find(params[:id])
    event = event_attendee.event

    if event_attendee&.destroy
      flash[:notice] = I18n.t(
        'event_attendee.messages.destroyed',
        name: event.name
      )
    end

    redirect_to params[:redirect] == 'dashboard_events' ? dashboard_events_path : events_path
  end
end
