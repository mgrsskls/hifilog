class Product < ApplicationRecord
  include Rails.application.routes.url_helpers

  nilify_blanks

  has_paper_trail skip: :updated_at

  extend FriendlyId

  belongs_to :brand, counter_cache: :products_count
  has_and_belongs_to_many :sub_categories, join_table: :products_sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :setups

  validates :name, presence: true
  validates :name, uniqueness: { scope: :brand, case_sensitive: false }
  validates :sub_categories, presence: true

  friendly_id :url_slug, use: :slugged

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      discontinued
      id
      name
      slug
      updated_at
      versions_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[brand setups sub_categories users]
  end

  def display_name
    "#{brand.name} #{name}"
  end

  def url_slug
    display_name.parameterize
  end

  def url
    product_url(id: friendly_id)
  end

  def release_date
    return nil if release_year.nil?
    return release_year.to_s if release_month.nil?

    formatted_month = release_month.to_s.rjust(2, '0')

    return "#{formatted_month}/#{release_year}" if release_day.nil?

    formatted_day = release_day.to_s.rjust(2, '0')

    "#{formatted_day}/#{formatted_month}/#{release_year}"
  end
end
