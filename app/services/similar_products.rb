# frozen_string_literal: true

# "Similar Products" on catalogue detail pages: products that fill the same role as this product,
# ranked by sub categories, custom attributes and price band. See README, section
# "Similar Products".
#
# A variant page shows the list of its parent product. Variants have no custom attributes of their
# own, so a list per variant would be almost the same list, with a cache entry for each variant.
#
# The ranked ids are cached, not the records. Thus, a changed name or image of a candidate shows
# immediately. A new or changed candidate gets into existing lists when the cache entry expires.
module SimilarProducts
  # Increase this value when you change the scoring (Query or Weights), to discard cached lists.
  CACHE_VERSION = 1
  CACHE_TTL = 24.hours
  # The same number of items as one group in "Related Products", so that both blocks look the same.
  LIMIT = RelatedProducts::Query::PER_GROUP

  def self.for(product:)
    ids = item_ids(product)
    return [] if ids.empty?

    items = load_items(ids)
    ids.filter_map { |id| items[id] }
  end

  def self.item_ids(product)
    sub_category_ids = product.sub_category_ids.sort

    Rails.cache.fetch(
      ['similar_products', CACHE_VERSION, product.cache_key_with_version, sub_category_ids],
      expires_in: CACHE_TTL
    ) do
      Query.new(product:, sub_category_ids:, limit: LIMIT).call
    end
  end

  # The same presenter data as the other catalogue lists, so that paths, thumbnails and dates are
  # the same everywhere.
  def self.load_items(ids)
    relation = ProductItem.where(id: ids).includes(:brand)
    relation = ProductItem.preload_list_possession_images(relation)
    relation = ProductItem.preload_sub_category_names(relation)
    relation.index_by(&:id)
  end
  private_class_method :load_items
end
