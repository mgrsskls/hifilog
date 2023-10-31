class Product < ApplicationRecord
  extend FriendlyId

  belongs_to :brand, optional: true
  has_and_belongs_to_many :sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :rooms

  validates :name, presence: true
  validates :brand_id, presence: true
  validates :sub_categories, presence: true

  friendly_id :name, use: :scoped, scope: :brand

  def self.ransackable_attributes(auth_object = nil)
    [
      "created_at",
      "discontinued",
      "id",
      "name",
      "slug",
      "updated_at",
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["brand", "rooms", "sub_categories", "users"]
  end
end
