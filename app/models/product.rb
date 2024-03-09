class Product < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper

  pg_search_scope :search_by_name_and_description,
                  against: [:name, :description],
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

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  extend FriendlyId

  belongs_to :brand, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :setup_possessions, dependent: :destroy
  has_many :setups, through: :setup_possessions
  has_many :product_variants, dependent: :destroy

  accepts_nested_attributes_for :product_variants, reject_if: lambda { |variant|
    variant['name'].blank? &&
      variant['description'].blank? &&
      variant['release_day'].blank? &&
      variant['release_month'].blank? &&
      variant['release_year'].blank?
  }
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
      description
      discontinued
      discontinued_day
      discontinued_month
      discontinued_year
      id
      name
      possessions_id
      possessions_user_id
      price
      price_currency
      product_variants_id
      release_day
      release_month
      release_year
      setup_possessions_id
      setup_possessions_setup_id
      slug
      slugs_id
      updated_at
      versions_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand setups sub_categories users]
  end

  def display_name
    return unless brand

    "#{brand.name} #{name}"
  end

  def url_slug
    display_name.parameterize
  end

  def path
    product_path(id: friendly_id)
  end

  def url
    product_url(id: friendly_id)
  end

  def release_date
    formatted_date(release_day, release_month, release_year)
  end

  def discontinued_date
    return unless discontinued?

    formatted_date(discontinued_day, discontinued_month, discontinued_year)
  end

  def display_price
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{price_currency}"
  end

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end

  private

  def formatted_date(day, month, year)
    return nil if year.nil?
    return year.to_s if month.nil?

    formatted_month = month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{year}" if day.nil?

    formatted_day = day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{year}"
  end
end
