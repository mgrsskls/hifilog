class SubCategory < ApplicationRecord
  extend FriendlyId

  belongs_to :category
  has_and_belongs_to_many :products, join_table: :products_sub_categories

  friendly_id :name, use: :scoped, scope: :category

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      category_id
      created_at
      id
      name
      slug
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category products]
  end

  def friendly_category_id
    category.friendly_id
  end
end
