class ProductVariant < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include Format
  include Description

  extend FriendlyId

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :description

  multisearchable against: [
    :name,
    :model_no,
    :description,
    :release_year
  ]

  has_paper_trail skip: [:updated_at, :product_id], ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :product
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :notes, dependent: :destroy
  has_many :product_options, dependent: :destroy

  friendly_id :slug_candidates, use: [:slugged, :scoped, :history], scope: :product

  accepts_nested_attributes_for :product_options
  validates_associated :product_options

  validates :name,
            uniqueness: { scope: [:product, :model_no, :release_day, :release_month, :release_year] }
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
            numericality: { only_integer: true }
  validates :discontinued, inclusion: { in: [true, false] }

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

  def path
    product_variant_path(product_id: product.friendly_id, id: slug)
  end

  def url
    product_variant_url(product_id: product.friendly_id, id: slug)
  end

  def release_date
    return if release_year.blank?

    Date.new(release_year.to_i, release_month.present? ? release_month.to_i : 1,
             release_day.present? ? release_day.to_i : 1)
  end

  def discontinued_date
    return unless discontinued?
    return if discontinued_year.blank?

    Date.new(discontinued_year.to_i, discontinued_month.present? ? discontinued_month.to_i : 1,
             discontinued_day.present? ? discontinued_day.to_i : 1)
  end

  def slug_candidates
    [
      [:name, :model_no],
      [:name, :model_no, :release_year],
      [:name, :model_no, :release_year, :release_month],
      [:name, :model_no, :release_year, :release_month, :release_day]
    ]
  end

  # :nocov:
  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      pg_search_document_id
      discontinued
      discontinued_eq
      diy_kit
      model_no
      name
      name_cont
      name_end
      name_eq
      name_start
      product_id
      product_id_eq
    ]
  end
  # :nocov:
end
