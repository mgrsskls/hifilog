# frozen_string_literal: true

# "Similar Brands" on brands#show and brands#similar: brands that make the same kind of products,
# ranked by the profile of their products, their active period, country, price level and
# attributes. See docs/similar-products.md, "Similar Brands".
#
# The ranked ids are cached, not the records. A product change touches its brand
# (`belongs_to :brand, touch: true`), so a change of the brand's own products makes a new cache
# key. A change of a candidate gets into existing lists when the cache entry expires.
module SimilarBrands
  # Increase this value when you change the scoring (Query or Weights), to discard cached lists.
  CACHE_VERSION = 1
  CACHE_TTL = 24.hours
  # The same number of items as the "Similar Products" block.
  LIMIT = SimilarProducts::LIMIT
  PER_PAGE = Kaminari.config.default_per_page
  # Upper bound for the `page` param. It is part of the cache key (see `ranked`), so an
  # unbounded value would let a crawler fill the cache with one-off entries.
  MAX_PAGE = 1_000

  # items:       the best candidates for the block on the show page
  # total_count: the number of all candidates, to show "View all" only when there are more
  Preview = Struct.new(:items, :total_count, keyword_init: true)

  def self.for(brand:)
    result = ranked(brand, limit: LIMIT, offset: 0)

    Preview.new(items: load_items(result.ids), total_count: result.total_count)
  end

  # One page of the full list, as a Kaminari array for the `paginate` view helper.
  def self.page(brand:, page:, per: PER_PAGE)
    page = page.to_i.clamp(1, MAX_PAGE)
    result = ranked(brand, limit: per, offset: (page - 1) * per)

    # With `total_count`, Kaminari does not slice the array: it already is the page.
    Kaminari.paginate_array(load_items(result.ids), total_count: result.total_count).page(page).per(per)
  end

  # Cached as plain data (ids and a count), not as a Query::Result.
  def self.ranked(brand, limit:, offset:)
    data = Rails.cache.fetch(
      ['similar_brands', CACHE_VERSION, brand.cache_key_with_version, limit, offset],
      expires_in: CACHE_TTL
    ) do
      Query.new(brand:, limit:, offset:).call.to_h
    end

    Query::Result.new(**data)
  end

  # Loads the brands with the data that the brand list needs. Keeps the order of `ids`.
  def self.load_items(ids)
    return [] if ids.empty?

    brands = Brand.where(id: ids).with_attached_logo.preload(sub_categories: [:category]).index_by(&:id)
    ids.filter_map { |id| brands[id] }
  end
  private_class_method :ranked, :load_items
end
