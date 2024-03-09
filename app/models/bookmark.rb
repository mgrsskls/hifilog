class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :product
  belongs_to :product_variant, optional: true

  validates :product_id, uniqueness: { scope: [:user_id, :product_variant_id] }
end
