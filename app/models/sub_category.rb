class SubCategory < ApplicationRecord
  extend FriendlyId

  default_scope { order(order: :asc, name: :asc) }

  belongs_to :category
  has_and_belongs_to_many :products, join_table: :products_sub_categories
  has_and_belongs_to_many :brands
  has_and_belongs_to_many :custom_attributes
  has_and_belongs_to_many :custom_products

  friendly_id :name, use: [:slugged]

  auto_strip_attributes :name, squish: true

  validates :name, uniqueness: { scope: :category }, presence: true
  validates :slug, uniqueness: { scope: :category }, presence: true

  after_save :invalidate_cache

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      category_id
      category_id_eq
      name
      name_cont
      name_end
      name_eq
      name_start
      order
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:

  private

  def invalidate_cache
    Rails.cache.delete('/menu_categories')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end
end
