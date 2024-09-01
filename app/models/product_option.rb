class ProductOption < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  nilify_blanks only: [:option]

  auto_strip_attributes :option, squish: true

  validates :option, presence: true
  validates :option,
            uniqueness: { scope: :product },
            if: -> { product.present? }
  validates :option,
            uniqueness: { scope: :product_variant },
            if: -> { product_variant.present? }

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      id_value
      option
      product_id
      product_variant_id
      updated_at
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      product
      product_variant
    ]
  end

  # This is used for dropdowns in active_admin
  def display_name
    option
  end
end
