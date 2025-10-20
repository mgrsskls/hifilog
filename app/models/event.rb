class Event < ApplicationRecord
  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[address country_code end_date name start_date url]
  end
  # :nocov:
end
