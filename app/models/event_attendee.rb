# frozen_string_literal: true

class EventAttendee < ApplicationRecord
  belongs_to :user
  belongs_to :event

  before_destroy :stash_event_for_attendance_cancel_activity
  after_commit :record_event_attendance_user_activity, on: :create
  after_destroy_commit :record_event_attendance_cancelled_user_activity

  validates :user, uniqueness: { scope: :event }

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at event_id id id_value updated_at user_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[event user]
  end
  # :nocov:

  private

  def record_event_attendance_user_activity
    UserActivities::Recorder.event_attendance(self)
  end

  def stash_event_for_attendance_cancel_activity
    @cancel_event_for_activity = event
  end

  def record_event_attendance_cancelled_user_activity
    ev = @cancel_event_for_activity
    UserActivities::Recorder.event_attendance_cancelled(user:, event: ev) if ev && user
  end
end
