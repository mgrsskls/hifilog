class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers
  include BrandHelper
  include PgSearch::Model
  pg_search_scope :search_by_name_and_description,
                  against: [:name, :description],
                  ignoring: :accents,
                  using: {
                    tsearch: {
                      any_word: true,
                    },
                    trigram: {
                      threshold: 0.3
                    },
                  },
                  ranked_by: ':trigram'

  nilify_blanks

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  extend FriendlyId

  has_many :products, dependent: :destroy
  has_and_belongs_to_many :sub_categories

  validates :name,
            presence: true,
            uniqueness: { case_sensitive: false }
  validates :founded_year,
            numericality: { only_integer: true },
            if: -> { founded_year.present? }

  friendly_id :name, use: [:slugged, :history]

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      country_code
      created_at
      discontinued
      full_name
      id
      name
      slug
      slugs_id
      updated_at
      website
      versions_id
      founded_day
      founded_month
      founded_year
      discontinued_day
      discontinued_month
      discontinued_year
      description
      sub_categories_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['products']
  end

  def categories
    @categories ||= all_sub_categories(self).map(&:category).uniq.sort_by(&:name)
  end

  def display_name
    name
  end

  def url
    brand_url(id: friendly_id)
  end

  def country_name
    return if country_code.nil?

    country = ISO3166::Country[country_code]

    return if country.nil?

    country.translations[I18n.locale.to_s] || country.common_name || country.iso_short_name
  end

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end

  def founded_date
    formatted_date(founded_day, founded_month, founded_year)
  end

  def discontinued_date
    return unless discontinued?

    formatted_date(discontinued_day, discontinued_month, discontinued_year)
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
