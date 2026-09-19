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
    associated_against: { brand: [:name, :abbreviation], product_series: [:name] }
  )

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment
  # See the uniqueness validation of `name` below and ProductSeriesAssignment.
  attr_accessor :skip_name_uniqueness

  belongs_to :brand, touch: true
  # Optional: most products are in no series. touch: true expires the series page caches, and the
  # series touches its brand in turn. See docs/product-series.md.
  belongs_to :product_series, optional: true, touch: true, counter_cache: :products_count,
                              inverse_of: :products
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories,
                                           after_add: :recalculate_completeness!,
                                           after_remove: :recalculate_completeness!
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
  # Two products with the same name are valid in two series (Fezz "Omega Lupi" in Evolution and in
  # Legacy): the series tells them apart in the slug and in the lists. Checked only when one of
  # the four values changes, so an old duplicate does not block an unrelated edit. A NULL series
  # is one group of its own.
  #
  # ProductSeriesAssignment sets #skip_name_uniqueness for the products of one submit: it checks
  # the same rule on the end state of all of them, before it writes the first one.
  validates :name,
            uniqueness: { scope: [:brand_id, :product_series_id, :model_no], message: :taken_in_series },
            if: :series_identity_changed?
  validate :product_series_of_same_brand
  validate :name_does_not_repeat_series_name
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

  # Newest release first. Products without a release date come after the ones with a date, the
  # most recently added first. A date with only a year comes after the dates with a month in the
  # same year. index_products_on_brand_newest_first has the same order, so the brand page reads
  # the first rows of a brand without a sort step.
  NEWEST_FIRST_ORDER_SQL = 'products.release_year DESC NULLS LAST, products.release_month DESC NULLS LAST, ' \
                           'products.release_day DESC NULLS LAST, products.created_at DESC, products.id DESC'
  scope :newest_first, -> { reorder(Arel.sql(NEWEST_FIRST_ORDER_SQL)) }
  scope :missing_description, -> { where(description: nil) }

  # Series from the product form: a name, not an id (see #product_series_name=).
  # prepend: true, because FriendlyId builds the slug in its own before_validation callback, and
  # the slug contains the series. These three must run first.
  before_validation :preserve_slug_for_series_change, prepend: true, if: :series_changed_for_slug?
  before_validation :clear_product_series_of_other_brand, prepend: true, if: -> { persisted? && brand_id_changed? }
  before_validation :assign_product_series_from_name, prepend: true, if: -> { @product_series_name_assigned }
  after_validation :merge_new_product_series_errors
  # Every write path lands here -- the product form, ActiveAdmin, ProductConversionService, the
  # console -- so units are normalised on the model rather than in the controller that happens
  # to do the type coercion. Guarded on the change so an ordinary save that never touched the
  # specs does not pay for a definitions lookup. See CustomAttribute.normalize_units.
  before_save :normalize_custom_attribute_units, if: :custom_attributes_changed?

  after_commit :invalidate_cache
  after_commit :update_brand_sub_categories
  after_commit :recalculate_completeness!, on: [:create, :update]
  after_create_commit :recalculate_brand_products_count
  after_destroy_commit :recalculate_products_count_after_destroy

  # Brand#display_name, so the brand's abbreviation where it has one: "B&O Beolab 90". The
  # brand's own pages lead with the same form; this is that rule applied in product context.
  # #url_slug below is built from this, which is why Brand re-slugs its products whenever
  # either of its name columns changes.
  def display_name
    return "#{brand.display_name} #{name}" if brand

    name
  end

  # The title plus the series, for plain text where the series can not be shown on its own line:
  # the <title> element, <select> options, ActiveAdmin, alt text. "Fezz Audio Omega Lupi
  # (Evolution series)". The visible <h1> uses #display_name and shows the series under it.
  def qualified_name
    return display_name if product_series.nil?

    "#{display_name} (#{product_series.label})"
  end

  # The series name is part of the slug, not of the title: two products with the same name in two
  # series must have two URLs, and the result must not depend on which one was added first.
  # "fezz-audio-evolution-omega-lupi". See docs/product-series.md, "Product name, title and slug".
  def url_slug
    return if display_name.blank?

    [brand&.display_name, product_series&.name, name, model_no].compact_blank.join(' ').parameterize
  end

  # The value of the series field in the product form.
  def product_series_name
    return @product_series_name if @product_series_name_assigned

    product_series&.name
  end

  # The product form sends the series as a name, so that one field can select an existing series
  # or create a new one. An empty value removes the series. The name is resolved in
  # #assign_product_series_from_name, when the brand is known.
  def product_series_name=(value)
    @product_series_name = value
    @product_series_name_assigned = true
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

  # simplecov:disable
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
      product_series_id
      product_series_id_eq
      sub_categories_id
      sub_categories_id_eq
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[product_series]
  end
  # simplecov:enable

  def should_generate_new_friendly_id?
    slug.blank? || name_changed? || model_no_changed? || series_changed_for_slug?
  end

  # A new series from the product form has no id yet, so product_series_id alone does not show
  # the change.
  def series_changed_for_slug?
    product_series_id_changed? || product_series&.new_record? || false
  end

  # A product's slug is built from Brand#display_name plus the product name (see
  # #display_name), but #should_generate_new_friendly_id? above only fires on the product's
  # own name / model_no. So a change to either of the brand's name columns would otherwise
  # leave every one of its products at a URL describing a title the page no longer shows --
  # which is the part that matters; the redirect is the easy part. Called from Brand's
  # after_update whenever `name` or `abbreviation` actually changed.
  #
  # Inline rather than queued: the app has no background job infrastructure, brand renames
  # are rare, and each product costs one UPDATE.
  #
  # Brand.no_touching (not Product's) because `belongs_to :brand, touch: true` touches the
  # *brand* record on save -- no_touching suppresses touches to the class it's called on, so
  # it has to be scoped to the class being touched, not the class doing the saving. Otherwise
  # this bounces a timestamp write back to the brand once per product, from inside the
  # brand's own after_update callback.
  #
  # `save` rather than `save!`: a product that fails its own validations for unrelated
  # reasons keeps its old slug, which still resolves through :history. Better that than a
  # legitimate brand rename being blocked by stale data on one of its products.
  def self.resync_slugs_for(brand)
    resync_slugs(brand.products.reload)
  end

  # Same as .resync_slugs_for, for any set of products. ProductSeries calls it after a rename and
  # after a delete, because the series name is part of the slug. ProductSeries.no_touching for the
  # same reason as Brand.no_touching above: `belongs_to :product_series, touch: true`.
  def self.resync_slugs(products)
    Brand.no_touching do
      ProductSeries.no_touching do
        products.find_each do |product|
          next if product.slug == product.normalize_friendly_id(product.url_slug)

          product.preserve_current_slug_in_history
          product.slug = nil
          product.save
        end
      end
    end
  end

  # Products slugged before :history was in use have no friendly_id_slugs row for their
  # current slug, and without one the old URL 404s the moment the slug changes instead of
  # 301-ing through FriendlyFinder.
  def preserve_current_slug_in_history
    return if slug.blank?
    return if FriendlyId::Slug.exists?(sluggable_type: 'Product', sluggable_id: id, slug:)

    FriendlyId::Slug.create!(
      sluggable_type: 'Product', sluggable_id: id, slug:, created_at: Time.current
    )
  end

  # Keeps completeness / specs_applicable / specs_filled in step with completeness_score /
  # applicable_highlighted_attributes / missing_highlighted_attributes -- the view no longer
  # computes them (see contribute_product_items v04), so this is the only place that does.
  # update_columns on purpose, same reasoning as Brand#recalculate_products_count!: a plain
  # #update would re-run every save callback, including this one.
  #
  # Fires from three places: an after_commit on this record's own create/update, and after_add /
  # after_remove on sub_categories -- the association write a plain `product.sub_categories << x`
  # performs outside of any save, which the after_commit alone would miss. Reset the memoized
  # applicable_highlighted_attributes first: a sub_categories change invalidates it, and this may
  # be the same in-memory record whose association just changed.
  # rubocop:disable Rails/SkipsModelValidations
  def recalculate_completeness!(*)
    return unless persisted?

    @applicable_highlighted_attributes = nil
    applicable = applicable_highlighted_attributes
    filled = applicable.size - missing_highlighted_attributes.size
    score = completeness_score
    return if completeness == score && specs_applicable == applicable.size && specs_filled == filled

    update_columns(completeness: score, specs_applicable: applicable.size, specs_filled: filled)
  end
  # rubocop:enable Rails/SkipsModelValidations

  # Recomputes every product in a sub category -- needed when a CustomAttribute's `highlighted`
  # flag or its own sub_categories change, since that widens or narrows every product in the
  # sub category at once, regardless of whether the product itself changed.
  #
  # Runs in SubCategoryCompletenessJob. `start` is the first product id to process; the job
  # passes its cursor here and gets each product back through the block to advance it.
  def self.recalculate_completeness_for_sub_category!(sub_category_id, start: nil)
    joins(:sub_categories).where(sub_categories: { id: sub_category_id }).find_each(start:) do |product|
      product.recalculate_completeness!
      yield product if block_given?
    end
  end

  # Enqueues one SubCategoryCompletenessJob for each sub category, in one insert. A sub
  # category can hold thousands of products, so this work must not run in the web request.
  def self.recalculate_completeness_for_sub_categories_later(sub_category_ids)
    jobs = sub_category_ids.uniq.map { |id| SubCategoryCompletenessJob.new(id) }
    ActiveJob.perform_all_later(jobs) if jobs.any?
  end

  private

  # A new series has no products yet, so there is nothing to compare with.
  def series_identity_changed?
    return false if skip_name_uniqueness
    return false if product_series&.new_record?

    new_record? || name_changed? || model_no_changed? || product_series_id_changed? || brand_id_changed?
  end

  def product_series_of_same_brand
    return if product_series.nil? || brand.nil?
    return if product_series.brand_id.nil? || product_series.brand_id == brand_id

    errors.add(:product_series, :other_brand)
  end

  # "Omega Lupi" in the series "Evolution", not "Evolution Omega Lupi": the series is stored one
  # time, on the series. Checked on word boundaries at the start and at the end. A name that is
  # the series name and nothing else is allowed.
  def name_does_not_repeat_series_name
    return if product_series.nil? || name.blank?

    series_name = product_series.name.to_s.squish
    return if series_name.blank? || name.casecmp?(series_name)

    escaped = Regexp.escape(series_name)
    return unless name.match?(/\A#{escaped}\s/i) || name.match?(/\s#{escaped}\z/i)

    errors.add(:name, :contains_series_name, series: series_name)
  end

  # The brand of a new product can be new too (inline brand in the product form), so a series is
  # only looked up when the brand is saved. Otherwise the series is new as well.
  def assign_product_series_from_name
    @product_series_name_assigned = false
    series_name = @product_series_name.to_s.squish

    if series_name.blank?
      self.product_series = nil
      return
    end

    return if brand.nil?

    existing = brand.persisted? ? ProductSeries.find_by(brand_id: brand.id, name: series_name) : nil
    self.product_series = existing || ProductSeries.new(brand:, name: series_name)
  end

  def clear_product_series_of_other_brand
    return if product_series.nil? || product_series.brand_id == brand_id
    return if product_series.new_record? && product_series.brand.equal?(brand)

    self.product_series = nil
  end

  # FriendlyId :history keeps the old slug only when a history row exists for it (see
  # #preserve_current_slug_in_history). The slug is read from the database, because FriendlyId can
  # have changed the attribute already.
  def preserve_slug_for_series_change
    return unless persisted?

    current = attribute_in_database(:slug)
    return if current.blank?
    return if FriendlyId::Slug.exists?(sluggable_type: 'Product', sluggable_id: id, slug: current)

    FriendlyId::Slug.create!(sluggable_type: 'Product', sluggable_id: id, slug: current, created_at: Time.current)
  end

  # A new series from the product form is saved with the product. Its own errors ("must not start
  # with the brand name") are more useful than the generic "Product series is invalid".
  def merge_new_product_series_errors
    return unless product_series&.new_record? && product_series.errors.any?

    errors.delete(:product_series)
    product_series.errors.each do |error|
      errors.add(:product_series_name, error.message)
    end
  end

  def normalize_custom_attribute_units
    self.custom_attributes = CustomAttribute.normalize_units(custom_attributes)
  end

  # Mirrors the SQL in db/views/contribute_product_items_v01.sql: the key must exist and hold
  # something that is neither JSON null nor an empty string. `.present?` would disagree on a
  # stored false.
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
    Rails.cache.delete_multi(
      ['/newest_products', '/newest_product_item_refs', '/products_count', '/home/totals']
    )

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

  def recalculate_brand_products_count
    brand&.recalculate_products_count!
  end

  # brand_id is a plain attribute, still readable on the in-memory (destroyed) record here — no
  # need to remember it before destroy the way ProductVariant does for its indirect brand link.
  def recalculate_products_count_after_destroy
    Brand.find_by(id: brand_id)&.recalculate_products_count!
  end
end
