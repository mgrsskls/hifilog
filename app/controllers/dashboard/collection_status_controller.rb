# frozen_string_literal: true

class Dashboard::CollectionStatusController < ApplicationController
  before_action :authenticate_user!

  def show
    # 1. Load bookmarks into a Set of strings like "Brand:5" or "Product:12"
    # This makes lookups O(1) instead of searching the array every time!
    bookmark_keys = current_user.bookmarks.pluck(:item_type, :item_id).to_set { |type, id| "#{type}:#{id}" }

    param_brands = params[:brands]
    param_products = params[:products]
    params_product_variants = params[:product_variants]
    param_events = params[:events]

    # Initialize empty arrays so the render doesn't break if params are missing
    brands = products = product_variants = events = []

    # --- BRANDS ---
    if param_brands.present?
      brand_ids = param_brands.map(&:to_i)

      # Pluck only the IDs we need to know ownership state!
      # Returns an array of tuples: [[brand_id, prev_owned_boolean], ...]
      poss_data = current_user.possessions
                              .joins(:product)
                              .where(products: { brand_id: brand_ids })
                              .pluck('products.brand_id', :prev_owned)

      brands = brand_ids.map do |brand_id|
        {
          id: brand_id,
          in_collection: poss_data.any? { |b_id, prev| b_id == brand_id && !prev },
          previously_owned: poss_data.any? { |b_id, prev| b_id == brand_id && prev },
          bookmarked: bookmark_keys.include?("Brand:#{brand_id}")
        }
      end
    end

    # --- PRODUCTS ---
    if param_products.present?
      product_ids = param_products.map(&:to_i)

      poss_data = current_user.possessions
                              .where(product_id: product_ids, product_variant_id: nil)
                              .pluck(:product_id, :prev_owned)

      products = product_ids.map do |product_id|
        {
          id: product_id,
          in_collection: poss_data.any? { |p_id, prev| p_id == product_id && !prev },
          previously_owned: poss_data.any? { |p_id, prev| p_id == product_id && prev },
          bookmarked: bookmark_keys.include?("Product:#{product_id}")
        }
      end
    end

    # --- PRODUCT VARIANTS ---
    if params_product_variants.present?
      variant_ids = params_product_variants.map(&:to_i)

      poss_data = current_user.possessions
                              .where(product_variant_id: variant_ids)
                              .pluck(:product_variant_id, :prev_owned)

      product_variants = variant_ids.map do |variant_id|
        {
          id: variant_id,
          in_collection: poss_data.any? { |pv_id, prev| pv_id == variant_id && !prev },
          previously_owned: poss_data.any? { |pv_id, prev| pv_id == variant_id && prev },
          bookmarked: bookmark_keys.include?("ProductVariant:#{variant_id}")
        }
      end
    end

    # --- EVENTS ---
    if param_events.present?
      event_ids = param_events.map(&:to_i)

      attendee_data = current_user.event_attendees
                                  .joins(:event)
                                  .where(event_id: event_ids)
                                  .pluck(:event_id, :end_date)

      events = param_events
               .map do |event_id|
        event_id = event_id.to_i
        {
          id: event_id,
          in_collection: attendee_data.any? do |event|
            event[0] == event_id && !event[1].past?
          end,
          previously_owned: attendee_data.any? do |event|
            event[0] == event_id && event[1].past?
          end,
          bookmarked: bookmark_keys.include?("Event:#{event_id}")
        }
      end
    end

    render json: { brands:, products:, product_variants:, events: }
  end

  def counts
    render json: {
      products: user_possessions_count(user: current_user, prev_owned: false),
      custom_products: user_custom_products_count(current_user),
      previous_products: user_possessions_count(user: current_user, prev_owned: true),
      setups: user_setups_count(current_user),
      bookmarks: user_bookmarks_count(current_user),
      events: user_events_count(current_user),
      notes: user_notes_count(current_user)
    }
  end
end
