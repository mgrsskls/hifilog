class Possession < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user
  belongs_to :product
  belongs_to :product_variant, optional: true

  has_many :setup_possessions, dependent: :destroy

  validates :product_id, uniqueness: { scope: [:user_id, :product_variant_id] }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      product_id
      product_variant_id
      user_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      product
      product_variant
      setup_possessions
      user
    ]
  end
end
