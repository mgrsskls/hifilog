# frozen_string_literal: true

# "More from this series" on product and variant pages: other base products of the same series,
# in the order of the series page (release date ascending, unknown dates last). See
# docs/product-series.md.
#
# The ids are cached, not the records, as in SimilarProducts. A product change touches its
# series, so the key changes when the series changes.
module SeriesProducts
  CACHE_TTL = 24.hours

  # series:      the ProductSeries
  # items:       ProductItem rows (base products only), in series order
  # total_count: the number of other products in the series. The page shows "View all" only
  #              when there are more than the block shows.
  Preview = Struct.new(:series, :items, :total_count, keyword_init: true)

  # nil when the product has no series or is the only product of its series.
  def self.for(product:)
    series = product.product_series
    return nil if series.nil?

    ids = Rails.cache.fetch(['series_products', series.cache_key_with_version, product.id], expires_in: CACHE_TTL) do
      series.sibling_products(except: product).pluck(:id)
    end
    return nil if ids.empty?

    Preview.new(series:, items: ProductItem.base_products_in_order(ids),
                total_count: [series.products_count - 1, ids.size].max)
  end
end
