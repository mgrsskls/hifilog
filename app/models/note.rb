class Note < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :user

  validates :text, presence: true

  validates :product, presence: true
  validates :product_variant, uniqueness: { scope: [:user, :product] }
end
