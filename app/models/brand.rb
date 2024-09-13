class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ApplicationHelper
  include FormatHelper
  include Description

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

  friendly_id :name, use: [:slugged, :history]

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
    formatted_date(founded_day, founded_month, founded_year)
  end

  def discontinued_date
    return unless discontinued?

    formatted_date(discontinued_day, discontinued_month, discontinued_year)
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
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

  def formatted_date(day, month, year)
    return nil if year.nil?
    return year.to_s if month.nil?

    formatted_month = month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{year}" if day.nil?

    formatted_day = day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{year}"
  end
end
