class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers

  nilify_blanks

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug]

  extend FriendlyId

  has_many :products, dependent: :destroy
  has_and_belongs_to_many :categories

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  friendly_id :name, use: [:slugged, :history]

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      categories_id
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
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['products']
  end

  def sub_categories
    @sub_categories ||= SubCategory.joins(:products).where(products:).order(:name).distinct
  end

  def categories
    @categories ||= sub_categories.includes([:category]).map(&:category).uniq.sort_by(&:name)
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
