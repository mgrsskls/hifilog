class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :product
  belongs_to :product_variant, optional: true
  belongs_to :bookmark_list, optional: true

  validates :product_id, uniqueness: { scope: [:user_id, :product_variant_id] }

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      bookmark_list_id_eq
      created_at
      id
      id_value
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:
end
