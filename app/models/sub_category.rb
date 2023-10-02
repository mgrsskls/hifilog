class SubCategory < ApplicationRecord
  belongs_to :category, optional: true
  has_many :product

  def self.ransackable_attributes(auth_object = nil)
    ["category_id", "created_at", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "product"]
  end
end
