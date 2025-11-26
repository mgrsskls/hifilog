class Event < ApplicationRecord
  has_many :event_attendees, dependent: :destroy
  has_many :users, through: :event_attendees

  def discontinued?
    return Time.zone.today > end_date if end_date.present?

    Time.zone.today > start_date
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[address country_code end_date name start_date url created_at updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[event_attendees users]
  end
  # :nocov:
end
