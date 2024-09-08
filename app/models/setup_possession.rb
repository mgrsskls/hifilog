class SetupPossession < ApplicationRecord
  belongs_to :setup
  belongs_to :possession

  validates :possession, uniqueness: true

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id
      id_value
      possession_id
      setup_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      possession
      setup
    ]
  end
  # :nocov:
end
