class SubCategory < ApplicationRecord
  extend FriendlyId

  belongs_to :category
  has_and_belongs_to_many :products

  friendly_id :name, use: :scoped, scope: :category

  def self.ransackable_attributes(auth_object = nil)
    [
      "category_id",
      "created_at",
      "id",
      "name",
      "slug",
      "updated_at",
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "products"]
  end

  def friendly_category_id
    category.friendly_id
  end
end
