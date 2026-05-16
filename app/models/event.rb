# frozen_string_literal: true

class Event < ApplicationRecord
  # Single source for config/routes.rb :slug constraint (no \A/\z — Rails forbids anchors there)
  # FriendlyId parameterize output matches this pattern.
  SLUG_PATTERN_SOURCE = '[a-z0-9]+(?:-[a-z0-9]+)*'
  SLUG_PATH_CONSTRAINT = Regexp.new(SLUG_PATTERN_SOURCE)
  SLUG_ROUTE_PATTERN = Regexp.new("\\A#{SLUG_PATTERN_SOURCE}\\z")

  extend FriendlyId

  has_many :event_attendees, dependent: :destroy
  has_many :users, through: :event_attendees

  before_validation :assign_calendar_year, prepend: true

  friendly_id :name, use: [:slugged, :scoped, :history], scope: :calendar_year

  validates :name, :start_date, presence: true
  validates :calendar_year, presence: true
  validates :slug, presence: true, uniqueness: { scope: :calendar_year }

  scope :past, -> { where(end_date: ..Time.zone.yesterday).or(where(start_date: ..Time.zone.yesterday, end_date: nil)) }
  scope :upcoming, -> { where(end_date: Time.zone.today..).or(where(start_date: Time.zone.today.., end_date: nil)) }

  scope :by_year, lambda { |year|
    where(start_date: Date.new(year.to_i, 1, 1)..Date.new(year.to_i, 12, 31))
  }

  def self.available_past_years
    # Pluck only years from past events for the filter menu
    past.pluck(:start_date).compact.map(&:year).uniq.sort.reverse
  end

  after_commit :flush_event_cache

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
    %w[address calendar_year country_code end_date name slug start_date url created_at updated_at slugs_id_eq]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[event_attendees users]
  end
  # :nocov:private

  def self.time_until_midnight
    (Date.tomorrow.beginning_of_day - Time.current).to_i.seconds
  end

  def flush_event_cache
    Rails.cache.delete('events/past_count')
    Rails.cache.delete('events/upcoming_count')
    Rails.cache.delete('events/country_codes')
    Rails.cache.delete('/newest_events')
  end

  def assign_calendar_year
    self.calendar_year = start_date&.year
  end
end
