# frozen_string_literal: true

# Reports, for a set of requested brand/product/product-variant/event ids, whether the
# given user currently owns, previously owned, or bookmarked each one.
class CollectionStatusQuery
  def initialize(user:, brand_ids: nil, product_ids: nil, product_variant_ids: nil, event_ids: nil)
    @user = user
    @brand_ids = brand_ids
    @product_ids = product_ids
    @product_variant_ids = product_variant_ids
    @event_ids = event_ids
  end

  def call
    {
      brands: brands_status,
      products: products_status,
      product_variants: product_variants_status,
      events: events_status
    }
  end

  private

  attr_reader :user

  def bookmark_keys
    @bookmark_keys ||= user.bookmarks.pluck(:item_type, :item_id).to_set { |type, id| "#{type}:#{id}" }
  end

  def brands_status
    return [] if @brand_ids.blank?

    brand_ids = @brand_ids.map(&:to_i)
    poss_data = user.possessions
                    .joins(:product)
                    .where(products: { brand_id: brand_ids })
                    .pluck('products.brand_id', :prev_owned)

    brand_ids.map do |brand_id|
      {
        id: brand_id,
        in_collection: poss_data.any? { |b_id, prev| b_id == brand_id && !prev },
        previously_owned: poss_data.any? { |b_id, prev| b_id == brand_id && prev },
        bookmarked: bookmark_keys.include?("Brand:#{brand_id}")
      }
    end
  end

  def products_status
    return [] if @product_ids.blank?

    product_ids = @product_ids.map(&:to_i)
    poss_data = user.possessions
                    .where(product_id: product_ids, product_variant_id: nil)
                    .pluck(:product_id, :prev_owned)

    product_ids.map do |product_id|
      {
        id: product_id,
        in_collection: poss_data.any? { |p_id, prev| p_id == product_id && !prev },
        previously_owned: poss_data.any? { |p_id, prev| p_id == product_id && prev },
        bookmarked: bookmark_keys.include?("Product:#{product_id}")
      }
    end
  end

  def product_variants_status
    return [] if @product_variant_ids.blank?

    variant_ids = @product_variant_ids.map(&:to_i)
    poss_data = user.possessions
                    .where(product_variant_id: variant_ids)
                    .pluck(:product_variant_id, :prev_owned)

    variant_ids.map do |variant_id|
      {
        id: variant_id,
        in_collection: poss_data.any? { |pv_id, prev| pv_id == variant_id && !prev },
        previously_owned: poss_data.any? { |pv_id, prev| pv_id == variant_id && prev },
        bookmarked: bookmark_keys.include?("ProductVariant:#{variant_id}")
      }
    end
  end

  def events_status
    return [] if @event_ids.blank?

    event_ids = @event_ids.map(&:to_i)
    attendee_data = user.event_attendees
                        .joins(:event)
                        .where(event_id: event_ids)
                        .pluck(:event_id, :end_date)

    event_ids.map do |event_id|
      {
        id: event_id,
        in_collection: attendee_data.any? { |event| event[0] == event_id && !event[1].past? },
        previously_owned: attendee_data.any? { |event| event[0] == event_id && event[1].past? },
        bookmarked: bookmark_keys.include?("Event:#{event_id}")
      }
    end
  end
end
