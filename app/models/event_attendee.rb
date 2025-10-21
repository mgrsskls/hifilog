class EventAttendee < ApplicationRecord
  belongs_to :user
  belongs_to :event

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at event_id id id_value updated_at user_id]
  end
  # :nocov:
end
