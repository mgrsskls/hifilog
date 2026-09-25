# frozen_string_literal: true

# "Similar Products" on catalogue detail pages: products that fill the same role as this product,
# ranked by sub categories, custom attributes and price band. See
# docs/similar-products.md.
#
# A variant page shows the list of its parent product. Variants have no custom attributes of their
# own, so a list per variant would be almost the same list, with a cache entry for each variant.
#
# The ranked ids are cached, not the records. Thus, a changed name or image of a candidate shows
# immediately. A new or changed candidate gets into existing lists when the cache entry expires.
module SimilarProducts
  # Increase this value when you change the scoring (Query or Weights), to discard cached lists.
  CACHE_VERSION = 2
  CACHE_TTL = 24.hours
  # The same number of items as one group in "Related Products", so that both blocks look the same.
  LIMIT = RelatedProducts::Query::PER_GROUP
  # Items on one page of the full list (products/:id/similar).
  PER_PAGE = Kaminari.config.default_per_page
  # Upper bound for the `page` param. It is part of the cache key (see `ranked`), so an
  # unbounded value would let a crawler fill the cache with one-off entries.
  MAX_PAGE = 1_000

  # items:       the best candidates for the block on the show page
  # total_count: the number of all candidates. The show page uses it to show "View all" only
  #              when the full list has more items than the block.
  Preview = Struct.new(:items, :total_count, keyword_init: true)

  def self.for(product:)
    result = ranked(product, limit: LIMIT, offset: 0)

    Preview.new(items: load_items(result.ids), total_count: result.total_count)
  end

  # One page of the full list, as a Kaminari array for the `paginate` view helper.
  def self.page(product:, page:, per: PER_PAGE)
    page = page.to_i.clamp(1, MAX_PAGE)
    result = ranked(product, limit: per, offset: (page - 1) * per)

    # With `total_count`, Kaminari does not slice the array: it already is the page.
    Kaminari.paginate_array(load_items(result.ids), total_count: result.total_count).page(page).per(per)
  end

  # Cached as plain data (ids and a count), not as a Query::Result: a cache entry must not
  # depend on a class that can change.
  def self.ranked(product, limit:, offset:)
    sub_category_ids = product.sub_category_ids.sort

    data = Rails.cache.fetch(
      ['similar_products', CACHE_VERSION, product.cache_key_with_version, sub_category_ids, limit, offset],
      expires_in: CACHE_TTL
    ) do
      Query.new(product:, sub_category_ids:, limit:, offset:).call.to_h
    end

    Query::Result.new(**data)
  end

  # The same presenter data as the other catalogue lists, so that paths, thumbnails and dates are
  # the same everywhere. Keeps the order of `ids`.
  def self.load_items(ids)
    return [] if ids.empty?

    relation = ProductItem.where(id: ids).includes(:brand)
    relation = ProductItem.preload_list_possession_images(relation)
    relation = ProductItem.preload_sub_category_names(relation)
    items = relation.index_by(&:id)
    ids.filter_map { |id| items[id] }
  end
  private_class_method :ranked, :load_items
end
