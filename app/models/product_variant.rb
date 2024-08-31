class ProductVariant < ApplicationRecord
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper

  extend FriendlyId

  belongs_to :product
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :notes, dependent: :destroy
  has_many :product_options, dependent: :destroy

  has_paper_trail skip: [:updated_at, :product_id], ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  friendly_id :slug_candidates, use: [:slugged, :scoped, :history], scope: :product

  nilify_blanks

  auto_strip_attributes :name, squish: true

  accepts_nested_attributes_for :product_options
  validates_associated :product_options

  validates :name,
            uniqueness: { scope: [:product, :release_year] }
  validates :name,
            presence: true,
            allow_blank: true
  validates :slug,
            presence: true
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
  validates :release_year,
            presence: true,
            if: -> { name.blank? }
  validates :product_id,
            presence: true,
            numericality: { only_integer: true }
  validates :discontinued, inclusion: { in: [true, false] }

  def release_date
    formatted_date(release_day, release_month, release_year)
  end

  def discontinued_date
    return unless discontinued?

    formatted_date(discontinued_day, discontinued_month, discontinued_year)
  end

  def name_with_fallback
    return 'Update' if name.blank?

    name
  end

  def short_name
    name_with_fallback
  end

  def display_name
    "#{product.brand.name} #{product.name} #{name_with_fallback}"
  end

  def display_price
    "#{number_with_delimiter number_to_rounded(price, precision: 2)} #{price_currency}"
  end

  def formatted_description
    return if description.blank?

    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(description)
  end

  def path
    product_variant_path(product_id: product.friendly_id, variant: slug)
  end

  def url
    product_variant_url(product_id: product.friendly_id, variant: slug)
  end

  def slug_candidates
    [
      [:name],
      [:release_year, :name],
      [:release_year, :release_month, :name],
      [:release_year, :release_month, :release_day, :name],
      [:release_year],
      [:release_year, :release_month],
      [:release_year, :release_month, :release_day]
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      discontinued
      discontinued_eq
      name
      name_cont
      name_end
      name_eq
      name_start
      product_id
      product_id_eq
    ]
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
