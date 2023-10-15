class Product < ApplicationRecord
  extend FriendlyId

  belongs_to :brand, optional: true
  has_and_belongs_to_many :sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :rooms

  validates :name, presence: true
  validates :brand_id, presence: true

  friendly_id :name, use: :scoped, scope: :brand

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "brand_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "brand", "sub_category"]
  end
end
