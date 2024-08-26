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
end
