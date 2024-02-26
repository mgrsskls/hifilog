class Product < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper

  pg_search_scope :search_by_display_name,
                  against: :name,
                  ignoring: :accents,
                  using: {
                    tsearch: {
                      any_word: true,
                    },
                    trigram: {
                      threshold: 0.2
                    },
                  },
                  ranked_by: ':trigram'

  nilify_blanks

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug]

  extend FriendlyId

  belongs_to :brand, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :setups

  accepts_nested_attributes_for :brand
  validates_associated :brand

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand, case_sensitive: false }
  validates :sub_categories, presence: true
  validates :price,
            numericality: true,
            comparison: { greater_than: 0 },
            if: -> { price.present? }
  validates :price_currency,
            presence: true,
            if: -> { price.present? }
  validates :release_day,
            numericality: { only_integer: true },
            comparison: { greater_than: 0, less_than: 32 },
            if: -> { release_day.present? }
  validates :release_month,
            numericality: { only_integer: true },
            comparison: { greater_than: 0, less_than: 13 },
            if: -> { release_month.present? }
  validates :release_year,
            numericality: { only_integer: true },
            comparison: { greater_than: 1899 },
            if: -> { release_year.present? }

  store_accessor :custom_attributes

  friendly_id :url_slug, use: [:slugged, :history]

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      discontinued
      id
      name
      slug
      slugs_id
      updated_at
      versions_id
      release_day
      release_month
      release_year
      description
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand setups sub_categories users]
  end

  def display_name
    "#{brand.name} #{name}"
  end

  def url_slug
    display_name.parameterize
  end

  def url
    product_url(id: friendly_id)
  end

  def release_date
    return nil if release_year.nil?
    return release_year.to_s if release_month.nil?

    formatted_month = release_month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{release_year}" if release_day.nil?

    formatted_day = release_day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{release_year}"
  end

  def price_set
    price.present?
  end

  def display_price
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{price_currency}"
  end
end
