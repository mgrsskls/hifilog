class ProductOption < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true

  nilify_blanks only: [:option, :model_no]

  auto_strip_attributes :option, squish: true
  auto_strip_attributes :model_no, squish: true

  validates :option, presence: true
  validates :option,
            uniqueness: { scope: :product },
            if: -> { product.present? }
  validates :model_no,
            uniqueness: { scope: :product },
            if: -> { model_no.present? && product.present? }
  validates :option,
            uniqueness: { scope: :product_variant },
            if: -> { product_variant.present? }
  validates :model_no,
            uniqueness: { scope: :product_variant },
            if: -> { model_no.present? && product_variant.present? }

  # This is used for dropdowns in active_admin
  # :nocov:
  def display_name
    return "#{option} (#{model_no})" if model_no.present?

    option
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[
      created_at
      id
      id_value
      option
      product_id
      product_variant_id
      updated_at
      model_no
    ]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[
      product
      product_variant
    ]
  end
  # :nocov:
end
