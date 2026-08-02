# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include Format
  include Completeness
  include Description
  include MetaDescription
  include PgSearchByName
  include DatePartsValidatable
  include ReleaseDate
  include DiscontinuedDate

  extend FriendlyId

  delegate_missing_to :product

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :description

  pg_search_by_name(against: { name: 'A', model_no: 'B' })

  has_paper_trail skip: [:updated_at, :product_id], ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :product, touch: true
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :notes, dependent: :destroy
  has_many :product_options, dependent: :destroy
  has_many :bookmarks, dependent: :destroy, as: :item

  friendly_id :slug_candidates, use: [:slugged, :scoped, :history], scope: :product

  accepts_nested_attributes_for :product_options
  validates_associated :product_options

  validates :name,
            uniqueness: { scope: [:product, :model_no, :release_day, :release_month, :release_year] }
  validates :name,
            presence: true,
            allow_blank: true
  validates :slug,
            presence: true
  validates :price,
            numericality: true,
            comparison: { greater_than: 0 },
            if: -> { price.present? }
  validates :price_currency,
            presence: true,
            if: -> { price.present? }
  validates_release_date_parts
  validates :release_year,
            presence: true,
            if: -> { name.blank? }
  validates :product_id,
            numericality: { only_integer: true }
  validates :discontinued, inclusion: { in: [true, false] }

  # Variants inherit the parent's custom attributes and cannot edit them, so specs are not
  # part of a variant's own completeness.
  COMPLETENESS_WEIGHTS = { description: 3, release_year: 2, discontinued_year: 1 }.freeze

  before_destroy :remember_brand_id_for_products_count
  after_commit :invalidate_cache
  after_create_commit :recalculate_brand_products_count
  after_destroy_commit :recalculate_remembered_brand_products_count

  # An entry still in production has no year of discontinuation to give, so it is only asked for
  # once the entry is marked discontinued.
  def completeness_fields
    return super - [:discontinued_year] unless discontinued?

    super
  end

  def name_with_fallback
    return 'Update' if name.blank?

    name
  end

  def short_name
    name_with_fallback
  end

  def display_name
    "#{product.brand.name} #{product.name} #{name_with_fallback}"
  end

  def path
    product_variant_path(product_id: product.friendly_id, id: slug)
  end

  def url
    product_variant_url(product_id: product.friendly_id, id: slug)
  end

  def meta_desc
    return truncate_meta(strip_tags(formatted_description)) if description.present?
    return product.meta_desc if product.description.present?

    meta_sentences(
      meta_identity_sentence,
      meta_lifecycle_sentence
    )
  end

  def slug_candidates
    [
      [:name, :model_no],
      [:name, :model_no, :release_year],
      [:name, :model_no, :release_year, :release_month],
      [:name, :model_no, :release_year, :release_month, :release_day]
    ]
  end

  # simplecov:disable
  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      pg_search_document_id
      discontinued
      discontinued_eq
      diy_kit
      model_no
      name
      name_cont
      name_end
      name_eq
      name_start
      product_id
      product_id_eq
    ]
  end
  # simplecov:enable

  def should_generate_new_friendly_id?
    slug.blank? ||
      name_changed? ||
      model_no_changed? ||
      release_year_changed? ||
      release_month_changed? ||
      release_day_changed?
  end

  private

  def meta_identity_sentence
    subject = meta_subject(product.name, name_with_fallback, ("(#{model_no})" if model_no.present?))

    "The #{subject} #{discontinued? ? 'were' : 'are'} #{product.sub_category_names.join(' / ')} " \
      "by #{meta_maker}."
  end

  # rubocop:disable Naming/PredicateMethod
  def invalidate_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('/newest_products')
    Rails.cache.delete('/products_count')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  def recalculate_brand_products_count
    product&.brand&.recalculate_products_count!
  end

  # Runs before destroy (not after) because the parent product may itself be mid-destroy in the
  # same transaction (has_many :product_variants, dependent: :destroy on Product) — by the time an
  # after_destroy_commit callback fires, `product` may no longer be loadable from the DB.
  def remember_brand_id_for_products_count
    @brand_id_for_products_count = product&.brand_id
  end

  def recalculate_remembered_brand_products_count
    Brand.find_by(id: @brand_id_for_products_count)&.recalculate_products_count!
  end
end
