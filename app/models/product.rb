# frozen_string_literal: true

class Product < ApplicationRecord
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

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :description

  pg_search_by_name(
    against: { name: 'A', model_no: 'B' },
    associated_against: { brand: [:name, :full_name] }
  )

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :brand, touch: true, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :product_variants, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :product_options, dependent: :destroy
  has_many :bookmarks, dependent: :destroy, as: :item

  friendly_id :url_slug, use: [:slugged, :history]

  accepts_nested_attributes_for :brand
  accepts_nested_attributes_for :product_options
  validates_associated :brand
  validates_associated :product_options

  validates :name, presence: true
  validates :slug, presence: true
  validates :model_no,
            uniqueness: { scope: :brand_id, allow_nil: true },
            allow_nil: true
  validates :sub_categories, presence: true
  validates :price,
            numericality: true,
            comparison: { greater_than: 0 },
            if: -> { price.present? }
  validates :price_currency,
            presence: true,
            if: -> { price.present? }
  validates_release_date_parts

  store_accessor :custom_attributes

  COMPLETENESS_WEIGHTS = { description: 3, release_year: 2, discontinued_year: 1 }.freeze
  # Specs are scored as one group so categories stay comparable: a headphone with four
  # highlighted attributes and a cable with none are both measured out of the same 8.
  COMPLETENESS_SPECS_WEIGHT = 3

  scope :missing_release_year, -> { where(release_year: nil) }
  scope :missing_description, -> { where(description: nil) }

  after_commit :invalidate_cache
  after_commit :update_brand_sub_categories

  def display_name
    return "#{brand.name} #{name}" if brand

    name
  end

  def url_slug
    return if display_name.blank?
    return "#{display_name} #{model_no}".parameterize if model_no.present?

    display_name.parameterize
  end

  def path
    product_path(id: friendly_id)
  end

  def url
    product_url(id: friendly_id)
  end

  def custom_attributes_resources
    CustomAttribute.where(label: custom_attributes&.keys).index_by(&:label)
  end

  def custom_attributes_list
    return unless custom_attributes.present? && custom_attributes.any?

    attributes = []
    custom_attributes.each do |custom_attribute|
      custom_attribute_resource = sub_categories.flat_map(&:custom_attributes).find do |sub_custom_attribute|
        sub_custom_attribute.id == custom_attribute[0].to_i
      end
      if custom_attribute_resource
        attributes.push I18n.t("custom_attributes.#{custom_attribute_resource.options[custom_attribute[1].to_s]}")
      end
    end

    attributes.join(', ')
  end

  # One indexed join per call, memoised, and never called from the contribute queues (those
  # filter in SQL instead), so this stays a single extra query on a product page.
  # An entry still in production has no year of discontinuation to give, so it is only asked for
  # once the entry is marked discontinued.
  def completeness_fields
    return super - [:discontinued_year] unless discontinued?

    super
  end

  def applicable_highlighted_attributes
    @applicable_highlighted_attributes ||=
      CustomAttribute.where(highlighted: true)
                     .joins(:sub_categories)
                     .where(sub_categories: { id: sub_category_ids })
                     .distinct
                     .pluck(:label)
  end

  # Not memoised: custom_attributes can change on a loaded record, and this is a cheap reject
  # over a handful of labels. The query it depends on is memoised above.
  def missing_highlighted_attributes
    applicable_highlighted_attributes.reject { |label| highlighted_attribute_filled?(label) }
  end

  # 2 points for the fraction filled, plus a final point only once the set is closed, so a
  # nearly finished entry outranks a half finished one.
  def completeness_components
    applicable = applicable_highlighted_attributes
    return super if applicable.empty?

    filled = applicable.size - missing_highlighted_attributes.size
    bonus = filled == applicable.size ? 1 : 0

    super + [[Rational(2 * filled, applicable.size) + bonus, COMPLETENESS_SPECS_WEIGHT]]
  end

  def sub_category_names
    sub_categories.map(&:name)
  end

  def meta_desc
    return truncate_meta(strip_tags(formatted_description)) if description.present?

    meta_sentences(
      meta_identity_sentence,
      meta_lifecycle_sentence,
      meta_variants_sentence
    )
  end

  def fully_discontinued?
    discontinued? && product_variants.all?(&:discontinued)
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      pg_search_document_id
      brand_id
      brand_id_eq
      discontinued
      discontinued_eq
      diy_kit
      model_no
      name
      name_cont
      name_end
      name_eq
      name_start
      sub_categories_id
      sub_categories_id_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:

  def should_generate_new_friendly_id?
    slug.blank? || name_changed? || model_no_changed?
  end

  private

  # Mirrors the SQL in db/views/product_items_v18.sql: the key must exist and hold something
  # that is neither JSON null nor an empty string. `.present?` would disagree on a stored false.
  def highlighted_attribute_filled?(label)
    value = (custom_attributes || {})[label]

    !value.nil? && value != ''
  end

  def meta_identity_sentence
    subject = meta_subject(name, ("(#{model_no})" if model_no.present?))

    "The #{subject} #{fully_discontinued? ? 'were' : 'are'} #{sub_category_names.join(' / ')} " \
      "by #{meta_maker}."
  end

  def meta_variants_sentence
    count = product_variants.size
    return if count.zero?
    return '1 variant is documented on HiFi Log.' if count == 1

    "#{count} variants are documented on HiFi Log."
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

  def update_brand_sub_categories
    return unless brand

    brand.sub_categories << (sub_categories - brand.sub_categories)
    brand.save
  end
end
