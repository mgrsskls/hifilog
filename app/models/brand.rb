class Brand < ApplicationRecord
  extend FriendlyId

  has_many :products

  validates :name, presence: true

  friendly_id :name, use: :slugged

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["products"]
  end

  def sub_categories
    sub_categories = []

    products.each do |product|
      product.sub_categories.each do |sub_category|
        sub_categories << sub_category
      end
    end

    sub_categories.uniq.sort_by{|c| c.name.downcase}
  end

  def categories
    categories = []

    products.each do |product|
      product.sub_categories.each do |sub_category|
        categories << sub_category.category
      end
    end

    categories.uniq.sort_by{|c| c.name.downcase}
  end
end
