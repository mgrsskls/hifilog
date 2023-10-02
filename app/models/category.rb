class Category < ApplicationRecord
  has_many :products
  has_many :sub_categories

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["products", "sub_categories"]
  end
end
