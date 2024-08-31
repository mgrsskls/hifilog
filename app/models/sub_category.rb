class SubCategory < ApplicationRecord
  extend FriendlyId

  belongs_to :category
  has_and_belongs_to_many :products, join_table: :products_sub_categories
  has_and_belongs_to_many :brands
  has_and_belongs_to_many :custom_attributes
  has_and_belongs_to_many :custom_products

  friendly_id :name, use: [:slugged]

  auto_strip_attributes :name, squish: true

  validates :name, uniqueness: { scope: :category }, presence: true
  validates :slug, uniqueness: { scope: :category }, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      category_id
      category_id_eq
      name
      name_cont
      name_end
      name_eq
      name_start
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
end
