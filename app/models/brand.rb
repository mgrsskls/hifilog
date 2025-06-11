class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ApplicationHelper
  include Format
  include Description

  multisearchable against: [:name, :description]
  pg_search_scope :search_by_name,
                  against: [:name],
                  ignoring: :accents,
                  using: {
                    tsearch: {
                      prefix: true,
                      any_word: true,
                    }
                  },
                  ranked_by: ':trigram'

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :website, squish: true
  auto_strip_attributes :full_name, squish: true
  auto_strip_attributes :description

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  extend FriendlyId

  has_many :products, dependent: :destroy
  has_and_belongs_to_many :sub_categories

  validates :name,
            presence: true,
            uniqueness: true
  validates :slug,
            presence: true,
            uniqueness: true
  validates :founded_year,
            numericality: { only_integer: true },
            if: -> { founded_year.present? }
  validate :country_code_has_allowed_value

  friendly_id :name, use: [:slugged, :history]

  after_destroy :invalidate_cache
  after_destroy :invalidate_count_cache
  after_save :invalidate_cache
  after_save :invalidate_count_cache

  def categories
    @categories ||= sub_categories.map(&:category).uniq.sort_by(&:name)
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
    return if founded_year.blank?

    Date.new(founded_year.to_i, founded_month.present? ? founded_month.to_i : 1,
             founded_day.present? ? founded_day.to_i : 1)
  end

  def discontinued_date
    return unless discontinued?
    return if discontinued_year.blank?

    Date.new(discontinued_year.to_i, discontinued_month.present? ? discontinued_month.to_i : 1,
             discontinued_day.present? ? discontinued_day.to_i : 1)
  end

  def country_code_has_allowed_value
    return if country_code.nil? || ISO3166::Country.all.map(&:alpha2).include?(country_code)

    errors.add(:country_code, 'is not a correct country code')
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
    Rails.cache.delete('/newest_brands')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end

  # rubocop:disable Naming/PredicateMethod
  def invalidate_count_cache
    # rubocop:enable Naming/PredicateMethod
    Rails.cache.delete('/brands_count')

    # recommended to return true, as Rails.cache.delete will return false
    # if no cache is found and break the callback chain.
    # rubocop:disable Style/RedundantReturn
    return true
    # rubocop:enable Style/RedundantReturn
  end
end
