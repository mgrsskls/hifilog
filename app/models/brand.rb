class Brand < ApplicationRecord
  include Rails.application.routes.url_helpers

  extend FriendlyId

  has_many :products, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  friendly_id :name, use: :slugged

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at id name updated_at discontinued slug]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['products']
  end

  def sub_categories
    @sub_categories ||= products.includes(:sub_categories).flat_map(&:sub_categories).uniq.sort_by(&:name)
  end

  def categories
    @categories ||= sub_categories.map(&:category).uniq.sort_by(&:name)
  end

  def display_name
    name
  end

  def url
    brand_url(id: friendly_id)
  end
end
