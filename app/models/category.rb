class Category < ApplicationRecord
  extend FriendlyId

  default_scope { order(order: :asc) }

  has_many :sub_categories, dependent: :destroy

  friendly_id :name, use: [:slugged]

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  auto_strip_attributes :name, squish: true

  after_destroy :invalidate_cache
  after_save :invalidate_cache

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      column
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
  # :nocov:

  private

  # rubocop:disable Naming/PredicateMethod
  def invalidate_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('/menu_categories')
    Rails.cache.delete('/categories_count')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end
end
