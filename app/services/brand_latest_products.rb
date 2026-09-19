# frozen_string_literal: true

# The newest products of a brand for the brand page: 8 in the "Products" section, and 4 per
# product series in the "Product series" section. "Newest" is Product::NEWEST_FIRST_ORDER_SQL:
# newest release first, then products without a release date, the most recently added first.
# Base products only, no variants. See docs/product-series.md, "Brand page".
#
# The ids are cached per brand, not the records, as in SimilarProducts. A product change touches
# its brand (and a series change too), so the key changes.
module BrandLatestProducts
  CACHE_TTL = 24.hours
  # Part of the cache keys. Increase it when the shape of a cached value changes, so that old
  # entries are not read with the new shape (as in SimilarProducts::CACHE_VERSION).
  CACHE_VERSION = 2
  # Entries of the list in the "Products" section and of each list in the "Product series"
  # section. When there are more products, the last entry is a "+n" link (shared/_products_preview).
  PRODUCTS_LIMIT = 8
  SERIES_LIMIT = 4

  # items:       ProductItem rows, newest first (at most PRODUCTS_LIMIT)
  # total_count: the number of base products of the brand
  Preview = Struct.new(:items, :total_count, keyword_init: true)

  # series:      the ProductSeries
  # items:       ProductItem rows, newest first (at most SERIES_LIMIT)
  # total_count: the number of products of the series
  SeriesPreview = Struct.new(:series, :items, :total_count, keyword_init: true)

  # The newest products of the brand, and the number of all its base products (for the "+n" entry
  # of the list, see shared/_products_preview). Two queries, both on the index
  # index_products_on_brand_newest_first: the first rows, and a count of the brand's rows. The
  # count is not brands.products_count, because that column also counts variants.
  def self.products(brand:, limit: PRODUCTS_LIMIT)
    key = ['brand_latest_products', CACHE_VERSION, brand.cache_key_with_version, limit]
    ids, total_count = Rails.cache.fetch(key, expires_in: CACHE_TTL) do
      products = Product.where(brand_id: brand.id)
      [products.newest_first.limit(limit).pluck(:id), products.count]
    end

    Preview.new(items: ProductItem.base_products_in_order(ids), total_count:)
  end

  # For each series in +series+ that has products: its newest products. In the order of +series+.
  #
  # One query for all series: a LATERAL subquery per series row reads the products of that series
  # (index on product_series_id) and keeps the newest +limit+. The work depends on the size of the
  # brand's series, not on the size of the catalog. The rows of all series load in one more query.
  def self.by_series(brand:, series:, limit: SERIES_LIMIT)
    series = series.select { |item| item.products_count.to_i.positive? }
    return [] if series.empty?

    key = ['brand_latest_products/series', CACHE_VERSION, brand.cache_key_with_version, limit]
    ids_by_series = Rails.cache.fetch(key, expires_in: CACHE_TTL) do
      ids_by_series(brand.id, limit)
    end

    rows = ProductItem.base_products_in_order(ids_by_series.values.flatten).index_by(&:product_id)
    series.filter_map do |item|
      ids = ids_by_series[item.id]
      next if ids.blank?

      SeriesPreview.new(series: item, items: ids.filter_map { |id| rows[id] }, total_count: item.products_count)
    end
  end

  # { series_id => [product ids, newest first] }. Plain data, so the cache entry does not depend
  # on a class.
  def self.ids_by_series(brand_id, limit)
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL.squish, { brand_id:, limit: }])
      SELECT latest.product_series_id, latest.id
      FROM product_series
      CROSS JOIN LATERAL (
        SELECT products.id, products.product_series_id
        FROM products
        WHERE products.product_series_id = product_series.id
        ORDER BY #{Product::NEWEST_FIRST_ORDER_SQL}
        LIMIT :limit
      ) latest
      WHERE product_series.brand_id = :brand_id
    SQL

    ActiveRecord::Base.connection.select_rows(sql).each_with_object({}) do |(series_id, id), memo|
      (memo[series_id.to_i] ||= []) << id.to_i
    end
  end
  private_class_method :ids_by_series
end
