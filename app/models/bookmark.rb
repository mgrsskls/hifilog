class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :product_id, uniqueness: { scope: [:user_id, :product_variant_id] }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      id_value
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
end
