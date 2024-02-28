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
  validates :year_founded,
            numericality: { only_integer: true },
            if: -> { year_founded.present? }

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
      year_founded
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
    country.translations[I18n.locale.to_s] || country.common_name || country.iso_short_name
  end
end
