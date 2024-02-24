class SubCategory < ApplicationRecord
  extend FriendlyId

  belongs_to :category
  has_and_belongs_to_many :products, join_table: :products_sub_categories
  has_and_belongs_to_many :brands
  has_and_belongs_to_many :custom_attributes

  friendly_id :name, use: :scoped, scope: :category

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      category_id
      created_at
      id
      name
      slug
      updated_at
      brands_id
      custom_attributes_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[category products custom_attributes]
  end
end
