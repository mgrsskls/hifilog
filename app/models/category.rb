class Category < ApplicationRecord
  extend FriendlyId

  has_many :sub_categories, dependent: :destroy

  friendly_id :name, use: :slugged

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      name
      slug
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    ['sub_categories']
  end

  def self.ordered
    order('LOWER(name)')
  end
end
