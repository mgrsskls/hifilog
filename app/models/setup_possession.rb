class SetupPossession < ApplicationRecord
  belongs_to :setup
  belongs_to :possession

  validates :possession, uniqueness: true, presence: true
  validates :setup, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[]
  end
end
