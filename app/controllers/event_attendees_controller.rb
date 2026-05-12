# frozen_string_literal: true

class EventAttendeesController < ApplicationController
  before_action :authenticate_user!

  def create
    if params[:event_id].blank?
      flash[:alert] = I18n.t(:generic_error_message)
      redirect_to events_path and return
    end

    @event = Event.find(params[:event_id])

    @event_attendee = current_user.event_attendees.new(
      event: @event
    )

    flash[:alert] = I18n.t(:generic_error_message) unless @event_attendee.save

    redirect_to event_path(year: @event.calendar_year, slug: @event.friendly_id)
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

    redirect_to event_path(year: event.calendar_year, slug: event.friendly_id)
  end
end
