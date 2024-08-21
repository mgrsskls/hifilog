class ProductOption < ApplicationRecord
  belongs_to :product, optional: true
  belongs_to :product_variant, optional: true
  belongs_to :product_option, optional: true

  nilify_blanks only: [:option]
end
