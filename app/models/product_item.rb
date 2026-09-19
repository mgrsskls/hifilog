# frozen_string_literal: true

class ProductItem < ApplicationRecord
  include PgSearch::Model
  include CatalogueProductRow
  include PgSearchByName

  pg_search_by_name(against: {
                      name: 'A',
                      variant_name: 'B',
                      model_no: 'B',
                      brand_name: 'A',
                      brand_abbreviation: 'A',
                      # The series is not part of the product name (docs/product-series.md), so
                      # "evolution omega lupi" needs this column to find the product.
                      series_name: 'B'
                    })

  # product_options.product_item_id points at this view's synthetic UUID, so this association
  # only makes sense here — an inferred `contribute_product_item_id` column does not exist.
  has_many :product_options, inverse_of: false

  # The base product rows of +product_ids+, in the order of +product_ids+, with what the list
  # partials need (brand, thumbnail, sub category names). For product lists whose order comes from
  # a query on +products+ (SeriesProducts, BrandLatestProducts).
  def self.base_products_in_order(product_ids)
    return [] if product_ids.empty?

    relation = where(item_type: 'Product', product_id: product_ids).includes(:brand)
    relation = preload_list_possession_images(relation)
    relation = preload_sub_category_names(relation)
    rows = relation.index_by(&:product_id)
    product_ids.filter_map { |id| rows[id] }
  end
end
