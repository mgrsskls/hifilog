# frozen_string_literal: true

class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ApplicationHelper
  include Completeness
  include Format
  include Description
  include MetaDescription
  include DiscontinuedDate
  include DateFromComponents
  include PgSearchByName

  pg_search_by_name(against: [:name, :full_name])

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :website, squish: true
  auto_strip_attributes :full_name, squish: true
  auto_strip_attributes :description

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment, :remove_logo

  extend FriendlyId

  has_many :products, -> { order(name: :asc) }, dependent: :destroy, inverse_of: :brand
  has_and_belongs_to_many :sub_categories

  has_one_attached :logo do |attachable|
    # Format conversion only — dimensions stay as uploaded (sizes are tuned in markup/CSS).
    attachable.variant :thumb, format: :webp
  end

  validates :name,
            presence: true,
            uniqueness: true
  validates :slug,
            presence: true,
            uniqueness: true
  validates :founded_year,
            numericality: { only_integer: true },
            if: -> { founded_year.present? }
  validates :country_code,
            inclusion: { in: ->(_) { ISO3166::Country.all.map(&:alpha2) } },
            allow_nil: true

  validate :validate_logo_content_type
  validate :validate_logo_file_size

  friendly_id :name, use: [:slugged, :history]

  COMPLETENESS_WEIGHTS = {
    description: 3,
    country_code: 2,
    discontinued: 2,
    discontinued_year: 1,
    founded_year: 1,
    website: 1
  }.freeze
  COMPLETENESS_PRODUCTS_WEIGHT = 5

  scope :without_products, -> { where(products_count: 0) }
  scope :missing_founded_year, -> { where(founded_year: nil) }
  scope :missing_description, -> { where(description: nil) }
  # `where.not(discontinued: true)` would exclude brands whose status is unknown, but those
  # are still asked for a website by #completeness_fields, which only exempts discontinued ones.
  scope :missing_website, -> { where(website: nil).where('brands.discontinued IS NOT TRUE') }
  scope :missing_country_code, -> { where(country_code: nil) }
  scope :missing_discontinued, -> { where(discontinued: nil) }
  scope :missing_discontinued_year, -> { where(discontinued_year: nil, discontinued: true) }
  scope :incomplete, -> { where('brands.completeness < 100') }

  before_save :clear_logo_when_remove_requested

  after_update :touch_products
  after_destroy :invalidate_cache
  after_save :invalidate_cache
  after_commit :clear_country_cache
  after_commit :clear_brands_cache

  # A brand out of business has no current website to link to, and one still trading has no year
  # of discontinuation. They swap places, and both weigh 1, so the denominator stays 14 either
  # way and scores stay comparable across the catalogue.
  def completeness_fields
    return super - [:discontinued_year] unless discontinued?

    super - [:website]
  end

  def completeness_present?(field)
    return !discontinued.nil? if field == :discontinued

    super
  end

  # Having any products at all is worth more than every other brand field combined; an empty
  # brand page has nothing on it worth reading.
  def completeness_components
    super + [[products_count.to_i.positive? ? COMPLETENESS_PRODUCTS_WEIGHT : 0,
              COMPLETENESS_PRODUCTS_WEIGHT]]
  end

  # products_count covers product_items (products + variants), matching ProductFilterService's
  # definition of "products" elsewhere. Recomputed (not incremented) so it self-heals regardless
  # of which side — Product or ProductVariant — triggered the change.
  # update_column on purpose: a plain #update would run after_update :touch_products, bulk-touching
  # every product on the brand just because a derived count changed.
  # rubocop:disable Rails/SkipsModelValidations
  def recalculate_products_count!
    update_column(
      :products_count,
      products.count + ProductVariant.joins(:product).where(products: { brand_id: id }).count
    )
  end
  # rubocop:enable Rails/SkipsModelValidations

  def categories
    # Avoid sub_categories.includes(:category) when already preloaded — that rebuilds a
    # relation and re-queries per brand (N+1 on brands#index).
    @categories ||= begin
      scs = if association(:sub_categories).loaded?
              sub_categories
            else
              sub_categories.includes(:category)
            end
      scs.map(&:category).uniq.sort_by(&:name)
    end
  end

  def display_name
    name
  end

  def url
    brand_url(id: friendly_id)
  end

  def country_name
    country_name_from_country_code country_code
  end

  def founded_date
    date_from_components(founded_year, founded_month, founded_day)
  end

  def formatted_description
    super || fallback_description
  end

  # Moved here from BrandsController#set_meta_desc so that the copy is testable and shared by
  # the show and products pages. A written description is used as-is; the generated summary
  # gains a sentence about how much of the brand is actually catalogued.
  def meta_desc
    return truncate_meta(strip_tags(formatted_description)) if description.present?

    generated = fallback_description
    return meta_sentences(strip_tags(generated), meta_catalog_sentence) if generated.present?

    meta_sentences(
      "#{name} #{discontinued? ? 'was' : 'is'} an audio hi-fi brand" \
      "#{" from #{country_name}" if country_name.present?}.",
      meta_catalog_sentence
    )
  end

  def self.active_country_codes
    Rails.cache.fetch('brands/active_country_codes') do
      where.not(country_code: nil)
           .distinct
           .pluck(:country_code)
           .map(&:upcase)
    end
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      pg_search_document_id
      country_code
      country_code_cont
      country_code_end
      country_code_eq
      country_code_start
      discontinued
      discontinued_eq
      name
      name_cont
      name_end
      name_eq
      name_start
      sub_categories_id
      sub_categories_id_eq
      logo_attachment_id_eq
      logo_blob_id_eq
      completeness_eq
      completeness_gt
      completeness_lt
      products_count_eq
      products_count_gt
      products_count_lt
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end
  # :nocov:

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  private

  # `products_count` is nil for every brand created before the counter cache was added and never
  # touched since, so fall back to a count for those rather than reporting zero products for a
  # brand that has some. Once the counter cache is backfilled this never issues a query.
  def meta_catalog_sentence
    count = products_count || products.count

    return 'Its products, specifications and history are documented on HiFi Log.' if count.zero?
    return '1 product is documented on HiFi Log.' if count == 1

    "#{count} products are documented on HiFi Log."
  end

  def clear_logo_when_remove_requested
    return unless ActiveModel::Type::Boolean.new.cast(remove_logo)

    self.remove_logo = nil

    pending_create = attachment_changes['logo'].is_a?(ActiveStorage::Attached::Changes::CreateOne)
    return if pending_create

    self.logo = nil
  end

  def validate_logo_content_type
    return unless logo.attached?

    allowed = %w[image/jpeg image/png image/gif image/webp]
    return if allowed.include?(logo.blob&.content_type)

    errors.add(:logo, :invalid_content_type)
  end

  def validate_logo_file_size
    return unless logo.attached?

    return if logo.blob&.byte_size.to_i <= 5_000_000

    errors.add(:logo, :too_large)
  end

  # rubocop:disable Naming/PredicateMethod
  def clear_brands_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('brands/all_by_name')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  # rubocop:disable Naming/PredicateMethod
  def clear_country_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('brands/active_country_codes')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  def touch_products
    # rubocop:disable Rails/SkipsModelValidations
    products.touch_all
    # rubocop:enable Rails/SkipsModelValidations
  end

  # rubocop:disable Naming/PredicateMethod
  def invalidate_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete_multi(['/newest_brands', '/brands_count'])

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  def fallback_description
    # rubocop:disable Layout/LineLength
    is_country_name_present = country_name.present?
    is_founded_year_present = founded_year.present?
    is_discontinued_year_present = discontinued_year.present?
    any_sub_categories_present = sub_categories.any?

    return nil unless is_country_name_present || is_founded_year_present || is_discontinued_year_present || any_sub_categories_present

    sub_categories = self.sub_categories.sort_by(&:category).map { |cat| cat.name.downcase }

    str = "<i>#{name}</i> #{discontinued? ? 'was' : 'is'} an audio brand"

    str += " from#{' the' if %w[BS KY CF KM CK CZ DO LA MV MH NL PH RU SC SB SY TC AE GB US UM].include?(country_code)} #{country_name}" if is_country_name_present

    if is_founded_year_present || is_discontinued_year_present
      str += ', which was'
      str += " founded in #{founded_year}" if is_founded_year_present
      str += ' and' if is_founded_year_present && is_discontinued_year_present
      str += " discontinued in #{discontinued_year}" if is_discontinued_year_present

      if any_sub_categories_present
        str += ". It #{discontinued? ? 'offered' : 'offers'}"
      end
    elsif any_sub_categories_present
      str += ", which #{discontinued? ? 'offered' : 'offers'}"
    end

    str += concatenate_sub_category_names(sub_categories)

    sanitize("<p>#{str}.</p>", tags: %w[p i])

    # rubocop:enable Layout/LineLength
  end

  def concatenate_sub_category_names(sub_categories)
    if sub_categories.size > 1
      " #{sub_categories[0...-1].join(', ')} and #{sub_categories[-1]}"
    else
      " #{sub_categories.first}"
    end
  end
end
