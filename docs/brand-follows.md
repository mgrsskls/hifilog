# Following brands

This document describes brand follows and the feed of followed brands. It uses Simplified
Technical English (ASD-STE100).

## 1. Model

**`BrandFollow`** (`user` → `brand`) subscribes a user to the new products and product variants of a brand.

It is simpler than `UserFollow` on purpose. A brand has no inbox and no block list. Thus, a brand
follow writes no activity row, sends no email, and can fail with a clear error message (not a
general one).

A follow is not a bookmark. A bookmark saves a brand, and it can be in a `BookmarkList`. A follow
subscribes to what happens next. The brand page has the two buttons, and one does not include the
other.

A product series cannot be followed. A user who follows the brand already gets each new product of
the series in the feed (see [product-series.md](product-series.md)).

## 2. The events are derived, not stored

**`BrandCatalogEvent`** is a read-only view. It has one row for each product and each variant:
`brand_id`, `occurred_at`, and the ids for the link.

The application does not write a `UserActivity` row for each follower. That would make one
contribution into as many inserts as the brand has followers. It would also leave old rows when a
product is deleted or moved to a different brand. The view reads `created_at`. It needs no write
path, no backfill and no cleanup job. A deleted product leaves the feed automatically, and a product
that moves to a different brand moves with its brand.

## 3. Read path

- Entries of followed brands show only in the dashboard feed of the owner. They never show on a
  public profile.
- They show only from the time when the follow was created. `UserActivityTimeline` applies the same
  rule to followed users.
- `BRAND_EVENT_LOOKBACK` limits how far back the query goes.

The feed has two sources and still paginates in the database:

1. One `UNION ALL` over keys (activity id, event id, `occurred_at`) is paginated.
2. The rows of the page load from each source by id.

The rendering uses the `Item` struct again. Thus, the grouping shows a sequence of entries of one
brand on the same day as one row. A brand with a logo shows it in the icon position of the row. A
brand without a logo shows the verb icon.

### 3.1 Links and text

- On a single row, the brand and the product are one link to the product page.
- On a grouped row, the brand is the subject and links to the brand page.

The verbs are `brand_product_listed` and `brand_variant_listed`. The text says _added to HiFi Log_,
not _new_. The event is a contributor who adds the entry to the catalog. It is not the brand that
releases the product. An announcement by a brand of its own product would be a different source
with its own verb.

## 4. Brand follows are public

The brand page lists its followers and links to a full list (`brands#followers`). A profile does not
list the brands that its owner follows (see
[users-and-social.md](users-and-social.md#3-public-profile-and-dashboard)). The follower list of the
brand shows the follows.

- **`User.listable_for`** decides which followers are listed (see
  [users-and-social.md](users-and-social.md#2-profile-visibility)).
- The follower count is the count of _listed_ followers, not of rows. A larger number would show the
  number of hidden followers by subtraction.
- For this reason, the count is not a counter cache column. It is two cached integers for each
  brand, one for each audience. A new or deleted follow expires them.
- `UserBlock` does not apply to these lists.

## 5. Out of scope

- No email for new entries of a followed brand.
- No `UserActivity` rows for brand events.
- No announcements by brands.
