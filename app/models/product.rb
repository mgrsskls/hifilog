class Product < ApplicationRecord
  belongs_to :manufacturer, optional: true
  belongs_to :category, optional: true
  belongs_to :sub_category, optional: true

  validates :name, presence: true
  validates :manufacturer_id, presence: true

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "manufacturer_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "manufacturer", "sub_category"]
  end
end
