# frozen_string_literal: true

class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ApplicationHelper
  include Format
  include Description
  include DiscontinuedDate
  include DateFromComponents
  include PgSearchByName

  pg_search_by_name(against: { name: 'A', full_name: 'B' })

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
  validates :country_code,
            inclusion: { in: ->(_) { ISO3166::Country.all.map(&:alpha2) } },
            allow_nil: true

  friendly_id :name, use: [:slugged, :history]

  after_destroy :invalidate_cache
  after_save :invalidate_cache

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
    date_from_components(founded_year, founded_month, founded_day)
  end

  def formatted_description
    super || fallback_description
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
