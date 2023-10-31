class Category < ApplicationRecord
  extend FriendlyId

  has_many :sub_categories

  friendly_id :name, use: :slugged

  def self.ransackable_attributes(auth_object = nil)
    [
      "created_at",
      "id",
      "name",
      "slug",
      "updated_at",
    ]
  end

  def self.ransackable_associations(auth_object = nil)
    ["sub_categories"]
  end

  def products
    sub_categories.flat_map { |sub_category| sub_category.products }
  end
end
