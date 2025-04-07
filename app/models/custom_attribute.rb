class CustomAttribute < ApplicationRecord
  has_and_belongs_to_many :sub_categories

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      sub_categories
      sub_categories_id
      label
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:
end
