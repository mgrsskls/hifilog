class AppNews < ApplicationRecord
  has_and_belongs_to_many :users

  def self.ransackable_attributes(_auth_object = nil)
    %w[]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
end