# frozen_string_literal: true

class ProductVariant < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PgSearch::Model
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::NumberHelper
  include Format
  include Description
  include PgSearchByName
  include DatePartsValidatable
  include ReleaseDate
  include DiscontinuedDate

  extend FriendlyId

  delegate_missing_to :product

  nilify_blanks

  auto_strip_attributes :name, squish: true
  auto_strip_attributes :description

  pg_search_by_name(against: { name: 'A', model_no: 'B' })

  has_paper_trail skip: [:updated_at, :product_id], ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :product, touch: true
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
  validates_release_date_parts
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
