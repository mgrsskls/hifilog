class Product < ApplicationRecord
  extend FriendlyId

  belongs_to :manufacturer, optional: true
  has_and_belongs_to_many :sub_categories
  has_and_belongs_to_many :users
  has_and_belongs_to_many :rooms

  validates :name, presence: true
  validates :manufacturer_id, presence: true

  friendly_id :name, use: :scoped, scope: :manufacturer

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "name", "manufacturer_id", "updated_at"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["category", "manufacturer", "sub_category"]
  end
end
