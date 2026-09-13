# frozen_string_literal: true

# Read-only projection of catalog entries as feed events: one row per product and one per
# variant, carrying the brand it belongs to and when it was added.
#
# The events are derived rather than stored. Writing a +UserActivity+ row per follower would turn
# one contribution into as many inserts as the brand has followers, and would leave rows behind
# whenever a product is deleted or moved to another brand. Reading +created_at+ needs no write
# path, no backfill and no cleanup.
class BrandCatalogEvent < ApplicationRecord
  belongs_to :brand
  belongs_to :product
  belongs_to :product_variant, optional: true

  scope :chronological, -> { order(occurred_at: :desc) }

  # Entries the viewer subscribed to, and only from the moment they subscribed -- the rule
  # +UserActivityTimeline+ already applies to followed users, so following a brand does not
  # replay its back catalog into the feed.
  scope :followed_by, lambda { |user_id|
    where(<<~SQL.squish, user_id:)
      EXISTS (
        SELECT 1 FROM brand_follows
        WHERE brand_follows.user_id = :user_id
          AND brand_follows.brand_id = brand_catalog_events.brand_id
          AND brand_catalog_events.occurred_at >= brand_follows.created_at
      )
    SQL
  }

  def variant?
    product_variant_id.present?
  end

  def readonly?
    true
  end
end
