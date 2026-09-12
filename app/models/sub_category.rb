# frozen_string_literal: true

class SubCategory < ApplicationRecord
  extend FriendlyId

  default_scope { order(order: :asc, name: :asc) }

  belongs_to :category, inverse_of: :sub_categories
  has_and_belongs_to_many :products, join_table: :products_sub_categories
  has_and_belongs_to_many :brands
  has_and_belongs_to_many :custom_attributes
  has_and_belongs_to_many :custom_products

  friendly_id :name, use: [:slugged, :history]

  auto_strip_attributes :name, squish: true

  validates :name, uniqueness: { scope: :category }, presence: true
  validates :slug, uniqueness: { scope: :category }, presence: true
  # Global, not scoped to category: RelatedProducts::Graph references sub categories by
  # identifier alone, so two categories cannot both answer to "switches".
  validates :identifier, presence: true, uniqueness: true
  validate :identifier_must_not_change, on: :update

  before_validation :assign_identifier, on: :create

  after_save :invalidate_cache

  # simplecov:disable
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
      slugs_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brands category custom_attributes custom_products products]
  end
  # simplecov:enable

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  private

  # Derived from the name on first save and never again. `slug` follows the name for URL and SEO
  # reasons; `identifier` is what RelatedProducts::Graph points at, so it has to outlive renaming.
  def assign_identifier
    return if identifier.present?
    return if name.blank?

    base = name.parameterize
    candidate = base
    suffix = 2
    while self.class.exists?(identifier: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.identifier = candidate
  end

  def identifier_must_not_change
    return unless identifier_changed?

    errors.add(
      :identifier,
      'cannot be changed. RelatedProducts::Graph references sub categories by identifier, so ' \
      'changing it would silently empty every pairing edge that points here. Rename `name` ' \
      'instead -- it is what readers see, and the slug follows it.'
    )
  end

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
