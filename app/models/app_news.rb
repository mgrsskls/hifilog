class AppNews < ApplicationRecord
  include ApplicationHelper

  has_and_belongs_to_many :users

  def formatted_text
    # rubocop:disable Rails/OutputSafety
    markdown_to_html(text).html_safe
    # rubocop:enable Rails/OutputSafety
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:
end
