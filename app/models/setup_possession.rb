class SetupPossession < ApplicationRecord
  belongs_to :setup
  belongs_to :possession

  validates :possession, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      id
      id_value
      possession_id
      product_id
      product_variant_id
      setup_id
    ]
  end
end
