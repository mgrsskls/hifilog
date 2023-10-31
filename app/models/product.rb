class Product < ApplicationRecord
  extend FriendlyId

  belongs_to :brand
  has_and_belongs_to_many :sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :setups

  validates :name, presence: true
  validates_uniqueness_of :name, scope: :brand
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
    ["brand", "setups", "sub_categories", "users"]
  end
end
