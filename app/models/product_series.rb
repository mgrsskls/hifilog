# frozen_string_literal: true

# A named product line of one brand, for example "Klipsch Heritage" or "Fezz Evolution". A
# product has zero or one series. A variant has no series of its own; it uses the series of its
# product. See docs/product-series.md.
#
# The name is stored one time, here. It is not part of the product name and not part of the
# visible product title, but it is part of the product slug (see Product#url_slug). Thus a
# rename of a series re-slugs its products, in the same way as a brand rename does.
#
# Years, discontinued status and categories are not stored. They come from the products of the
# series (see #stats), so they can not become stale.
class ProductSeries < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Description
  include MetaDescription

  extend FriendlyId

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :description

  # No :touch: a product save touches its series, and PaperTrail records every touch as a version
  # without changes. See docs/catalog-model.md, "Changelog".
  has_paper_trail on: [:create, :update, :destroy], skip: :updated_at,
                  ignore: [:created_at, :id, :slug, :products_count], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :brand, touch: true
  has_many :products, dependent: :nullify, inverse_of: :product_series

  friendly_id :name, use: [:slugged, :scoped, :history], scope: :brand

  validates :name, presence: true, uniqueness: { scope: :brand_id }
  validates :slug, presence: true
  validate :name_does_not_start_with_brand_name

  after_update :resync_product_slugs, if: :saved_change_to_name?
  # The products lose the series before the row is deleted. Each product is saved, so that its
  # changelog and the changelog of the series show the removal. Their ids are kept, and their
  # slugs are made again after the commit. dependent: :nullify above then has no rows to change.
  before_destroy :detach_products, prepend: true
  after_destroy_commit :resync_former_product_slugs

  # "More from this series" on product pages. Same size as one group of Related Products.
  SIBLINGS_LIMIT = RelatedProducts::Query::PER_GROUP

  # Derived values of one series. See docs/product-series.md, "Derived values".
  Stats = Struct.new(:products_count, :start_year, :end_year, :all_discontinued, keyword_init: true) do
    # "1946 – present", "2015 – 2021" or nil when no year is known.
    def years_label
      return nil if start_year.nil? && end_year.nil?

      finish = all_discontinued ? end_year : I18n.t('product_series.present')
      [start_year || '?', finish || '?'].join(' – ')
    end

    def discontinued?
      all_discontinued == true
    end
  end

  EMPTY_STATS = Stats.new(products_count: 0, start_year: nil, end_year: nil, all_discontinued: nil).freeze

  # The text for running text and titles: "Evolution series". A name that already ends with
  # "series" (B&W "800 Series") is used as it is, so that the page never shows "800 Series series".
  def label
    return name if name.to_s.match?(/\bseries\z/i)

    "#{name} #{I18n.t('product_series.label_suffix')}"
  end

  # "Klipsch Heritage": the brand in its display form, then the series name.
  def display_name
    "#{brand.display_name} #{name}"
  end

  # "Klipsch Heritage series"
  def display_label
    "#{brand.display_name} #{label}"
  end

  def path
    brand_series_path(brand_id: brand.friendly_id, id: friendly_id)
  end

  def url
    brand_series_url(brand_id: brand.friendly_id, id: friendly_id)
  end

  # The versions of the series and the versions of the products that were added to it or removed
  # from it, oldest first. See docs/product-series.md, "Changelog and contributors".
  def changelog_versions
    PaperTrail::Version.where(item_type: 'ProductSeries', item_id: id)
                       .or(PaperTrail::Version.for_product_series(id))
                       .order(:created_at, :id)
  end

  def stats
    @stats ||= self.class.stats_query(Product.where(product_series_id: id))[id] || EMPTY_STATS
  end

  # The sub categories of the products of the series, ordered like the category menu. A series
  # has no categories of its own.
  def sub_categories
    SubCategory.joins(:products)
               .where(products: { product_series_id: id })
               .includes(:category)
               .distinct
  end

  def meta_desc
    return truncate_meta(strip_tags(formatted_description)) if description.present?

    categories = sub_categories.map(&:name).uniq
    meta_sentences(
      "All products of the #{display_label}" \
      "#{": #{categories.join(', ')}" if categories.any?}.",
      stats.years_label.present? ? "Produced #{stats.years_label}." : nil,
      'Specifications and history are documented on HiFi Log.'
    )
  end

  # Visible base products of the series, other than +product+, in the default order of the
  # series page. Served by index_products_on_series_and_release_date.
  def sibling_products(except:, limit: SIBLINGS_LIMIT)
    products.where.not(id: except.id)
            .reorder(Arel.sql(self.class.release_order_sql('products')))
            .limit(limit)
  end

  def self.stats_query(products)
    products.group(:product_series_id)
            .pluck(
              :product_series_id,
              Arel.sql('COUNT(*)'),
              Arel.sql('MIN(products.release_year)'),
              Arel.sql('MAX(products.discontinued_year)'),
              Arel.sql('BOOL_AND(products.discontinued)')
            )
            .to_h do |series_id, count, start_year, end_year, all_discontinued|
              [series_id, Stats.new(products_count: count, start_year:, end_year:, all_discontinued:)]
            end
  end

  # Release date ascending, unknown dates last, then id. Used by the series page and by
  # "More from this series", so both show the same order.
  def self.release_order_sql(table)
    %w[release_year release_month release_day].map { |column| "#{table}.#{column} ASC NULLS LAST" }
                                              .push("#{table}.id ASC")
                                              .join(', ')
  end

  # simplecov:disable
  def self.ransackable_attributes(_auth_object = nil)
    %w[brand_id created_at id name name_cont name_eq name_start products_count updated_at]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand]
  end
  # simplecov:enable

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  # The id, not the slug (FriendlyId's default): the slug is unique only within the brand, so a
  # URL with the slug alone, as ActiveAdmin builds from to_param, can not find the series. The
  # public URLs give the brand and the slug explicitly (#path, #url).
  def to_param
    id&.to_s
  end

  private

  # "Heritage", not "Klipsch Heritage": the brand is shown next to the series everywhere. Checked
  # on word boundaries, so "Klipschorn" is not refused for the brand "Klipsch".
  def name_does_not_start_with_brand_name
    return if name.blank? || brand.nil?

    prefixes = [brand.name, brand.abbreviation].compact_blank
    return unless prefixes.any? { |prefix| name.match?(/\A#{Regexp.escape(prefix)}(\s|\z)/i) }

    errors.add(:name, :starts_with_brand_name, brand: brand.display_name)
  end

  def resync_product_slugs
    Product.resync_slugs(Product.where(product_series_id: id))
  end

  # validate: false, as the dependent: :nullify before it did not validate either: an old product
  # that fails a validation for another reason must not block the delete. The slug is made again
  # in #resync_former_product_slugs, because the slug callbacks run in the validation.
  # ProductSeries.no_touching, because the series is deleted.
  def detach_products
    @former_product_ids = products.ids

    ProductSeries.no_touching do
      products.find_each do |product|
        product.product_series = nil
        product.save!(validate: false)
      end
    end
  end

  def resync_former_product_slugs
    return if @former_product_ids.blank?

    Product.resync_slugs(Product.where(id: @former_product_ids))
  end
end
