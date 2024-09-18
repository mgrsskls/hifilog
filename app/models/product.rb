class Product < ApplicationRecord
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

  multisearchable against: [:name, :description]

  has_paper_trail skip: :updated_at, ignore: [:created_at, :id, :slug], meta: { comment: :comment }
  attr_accessor :comment

  belongs_to :brand, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_many :possessions, dependent: :destroy
  has_many :users, through: :possessions
  has_many :product_variants, dependent: :destroy
  has_many :notes, dependent: :destroy
  has_many :product_options, dependent: :destroy

  friendly_id :url_slug, use: [:slugged, :history]

  accepts_nested_attributes_for :brand
  accepts_nested_attributes_for :product_options
  validates_associated :brand
  validates_associated :product_options

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand }
  validates :slug, presence: true
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

  def display_name
    return "#{brand.name} #{name}" if brand

    name
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

  def custom_attributes_list
    return unless custom_attributes.present? && custom_attributes.any?

    attributes = []
    custom_attributes.each do |custom_attribute|
      custom_attribute_resource = sub_categories.flat_map(&:custom_attributes).find do |sub_custom_attribute|
        sub_custom_attribute.id == custom_attribute[0].to_i
      end
      if custom_attribute_resource
        attributes.push I18n.t("custom_attributes.#{custom_attribute_resource.options[custom_attribute[1].to_s]}")
      end
    end

    attributes.join(', ')
  end

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      brand_id
      brand_id_eq
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
end
