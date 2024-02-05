class Product < ApplicationRecord
  include Rails.application.routes.url_helpers

  extend FriendlyId

  belongs_to :brand, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :setups

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand, case_sensitive: false }
  validates :sub_categories, presence: true

  friendly_id :name, use: :scoped, scope: :brand

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      discontinued
      id
      name
      slug
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand setups sub_categories users]
  end

  def display_name
    "#{brand.name} #{name}"
  end

  def url
    brand_product_url(id: friendly_id, brand_id: brand.friendly_id)
  end
end
