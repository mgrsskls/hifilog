class Category < ApplicationRecord
  extend FriendlyId

  has_many :sub_categories, dependent: :destroy

  friendly_id :name, use: [:slugged]

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  auto_strip_attributes :name, squish: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      name
      slug
      updated_at
      order
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['sub_categories']
  end

  def self.ordered
    order('LOWER(name)')
  end

  def ordered_sub_categories
    sub_categories.order(&:name)
  end
end
