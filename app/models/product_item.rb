# frozen_string_literal: true

class ProductItem < ApplicationRecord
  include PgSearch::Model
  include CatalogueProductRow
  include PgSearchByName

  pg_search_by_name(against: {
                      name: 'A',
                      variant_name: 'B',
                      model_no: 'B',
                      brand_name: 'A'
                    })

  # product_options.product_item_id points at this view's synthetic UUID, so this association
  # only makes sense here — an inferred `contribute_product_item_id` column does not exist.
  has_many :product_options, inverse_of: false
end
