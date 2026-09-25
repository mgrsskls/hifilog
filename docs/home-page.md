# Home page

This document describes the home page. It uses Simplified Technical English (ASD-STE100).

The home page is for visitors who are not signed in. The application sends a signed-in user to the
dashboard.

The page has three written sections: **Discover**, **Collect** and **Contribute**. Live blocks are
around them. Thus, the page shows that the database changes, and does not only describe it.

| Block                  | Source                                                              | Position                 |
| ---------------------- | ------------------------------------------------------------------- | ------------------------ |
| Pulse line             | Counts of the last seven days                                       | Below the intro headline |
| **Just added**         | Newest `product_items` rows and brands, merged by date              | Above Discover           |
| **Seen in real rooms** | Newest photos from collections that can be indexed publicly         | Above Collect            |
| **Coming up**          | `Event.upcoming`, with attendee counts                              | Below Collect            |
| **Last edits**         | Newest `PaperTrail::Version` rows for brands, products and variants | In Contribute            |
| Totals                 | Catalog counts, photos and countries                                | Above the footer         |

**`HomeHighlights`** gives the data for all six blocks. It gives plain structs, not models. Thus,
the partials do not need to know the models.

These rules apply to each block:

- A block never orders a large table on a column without an index. See the migration
  `AddHomeHighlightIndexes`, and the cache of the newest entries in
  [catalog-listing-and-search.md](catalog-listing-and-search.md#5-newest-entries).
- A block can be empty. The template then does not show that section, and does not show an empty
  heading.
- Photos obey the same visibility rule as catalog thumbnails: only profiles that can be indexed
  publicly. A photo links to the product or product variant, never to its owner.

The home page counts are cached.
