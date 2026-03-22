class Event < ApplicationRecord
  has_many :event_attendees, dependent: :destroy
  has_many :users, through: :event_attendees

  scope :past, -> { where(end_date: ..Time.zone.yesterday).or(where(start_date: ..Time.zone.yesterday, end_date: nil)) }
  scope :upcoming, -> { where(end_date: Time.zone.today..).or(where(start_date: Time.zone.today.., end_date: nil)) }

  after_commit :flush_event_counts

  def self.cached_past_count
    Rails.cache.fetch('events/past_count', expires_in: time_until_midnight) do
      past.count
    end
  end

  def self.cached_upcoming_count
    Rails.cache.fetch('events/upcoming_count', expires_in: time_until_midnight) do
      upcoming.count
    end
  end

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
  # :nocov:private

  def self.time_until_midnight
    (Date.tomorrow.beginning_of_day - Time.current).to_i.seconds
  end

  def flush_event_counts
    Rails.cache.delete('events/past_count')
    Rails.cache.delete('events/upcoming_count')
  end
end
