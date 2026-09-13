# frozen_string_literal: true

# Maps +BrandCatalogEvent+ rows to feed +Item+ structs.
#
# Unlike the activity builders, nothing here reads snapshotted metadata: the event *is* the
# catalog row, so a renamed brand shows its current name and a deleted product produces no row
# at all.
#
# +display_name+ is the full catalog title, brand included, because the row links the whole of it
# to the product page rather than sending the brand somewhere else mid-sentence. It is composed
# from the brand already loaded with the event rather than from +Product#display_name+, which
# would reach through +product.brand+ and load one brand per row.
module UserActivityTimeline::ItemBuilders::BrandItems
  private

  def brand_items(events)
    events.filter_map { |event| brand_catalog_event_item(event) }
  end

  def brand_catalog_event_item(event)
    brand = event.brand
    product = event.product
    return nil if brand.nil? || product.nil?

    variant = event.product_variant
    return brand_variant_item(event, brand, product, variant) if variant

    brand_item(
      event, brand,
      verb: :brand_product_listed,
      display_name: "#{brand.display_name} #{product.name}",
      url: product.path
    )
  end

  def brand_variant_item(event, brand, product, variant)
    brand_item(
      event, brand,
      verb: :brand_variant_listed,
      display_name: "#{brand.display_name} #{product.name} #{variant.name_with_fallback}",
      url: variant.path
    )
  end

  def brand_item(event, brand, verb:, display_name:, url:)
    UserActivityTimeline::Item.new(
      verb:,
      logged_at: event.occurred_at,
      display_name:,
      url:,
      brand_id: brand.id,
      brand_name: brand.display_name,
      brand_url: brand_path(id: brand.friendly_id),
      brand_logo: (brand.logo if brand.logo.attached?)
    )
  end
end
