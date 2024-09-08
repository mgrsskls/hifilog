class Note < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :user

  validates :text, presence: true

  validates :product, presence: true
  validates :product_variant, uniqueness: { scope: [:user, :product] }

  # :nocov:
  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      id_value
      text
      updated_at
      user_id
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      user
    ]
  end
  # :nocov:
end
