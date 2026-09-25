# Code structure

This document describes where the application keeps logic that is not in a model or a view:
services, controller concerns, presenters, caching and attachments. It uses Simplified Technical
English (ASD-STE100).

## 1. Services

Service objects hold orchestration and queries over many models. This logic belongs to neither a
model nor a controller.

| Service                                                                        | Role                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`ProductFilterService`**, **`BrandFilterService`**                           | Filters, sorting and name search on catalog and brand index pages. They share `FilterableService`, `FilterConstants` and `RelevanceOrdering`. See [catalog-listing-and-search.md](catalog-listing-and-search.md). |
| **`ProductCatalogShowService`**                                                | Context of the product and variant pages. See [catalog-model.md](catalog-model.md#7-product-and-variant-pages).                                                                                                   |
| **`SimilarProducts`**, **`SimilarProducts::Query`**                            | "Similar Products": ranking, pagination and cache. See [similar-products.md](similar-products.md).                                                                                                                |
| **`SimilarBrands`**, **`SimilarBrands::Query`**                                | "Similar Brands": ranking, pagination and cache. See [similar-products.md](similar-products.md#2-similar-brands).                                                                                                 |
| **`RelatedProducts::Resolver`**, **`RelatedProducts::Query`**                  | "Related Products": targets, gates and candidates. See [related-products.md](related-products.md).                                                                                                                |
| **`ProductConversionService`**                                                 | Converts a product into a variant of another product, and back. Never moves an entry to a different brand.                                                                                                        |
| **`CollectionStatusQuery`**                                                    | Owned, previously owned and bookmarked state for a set of ids, in one query, for the collection buttons on the client.                                                                                            |
| **`UserImagesQuery`**                                                          | Paginated feed of community images from possessions and custom products.                                                                                                                                          |
| **`StatisticsService`**                                                        | Collection statistics (Insights) for the dashboard and the profile. See [collection.md](collection.md#7-statistics-insights).                                                                                     |
| **`CacheService`**                                                             | Caches for the taxonomy, counts and definitions.                                                                                                                                                                  |
| **`SeriesProducts`**                                                           | "More from this series" on product and variant pages. See [product-series.md](product-series.md).                                                                                                                 |
| **`ProductSeriesAssignment`**                                                  | One submit of the series edit form: the series and the product checkboxes.                                                                                                                                        |
| **`BrandLatestProducts`**                                                      | The newest products of a brand and of each of its series, for the brand page.                                                                                                                                     |
| **`HomeHighlights`**                                                           | The live blocks of the home page. See [home-page.md](home-page.md).                                                                                                                                               |
| **`SitemapBuilder`**                                                           | Sitemap pages and their `lastmod` timestamps.                                                                                                                                                                     |
| **`PossessionPresenterService`**                                               | Selects the presenter for a possession.                                                                                                                                                                           |
| **`NewsletterUnsubscribeService`**, **`FollowNotificationUnsubscribeService`** | Unsubscribe with a signed token. See [users-and-social.md](users-and-social.md#7-unsubscribe-from-emails).                                                                                                        |
| **`UserActivities::Recorder`** / **`Backfill`**, **`UserActivityTimeline`**    | Write and read paths of the activity feed. See [user-activity.md](user-activity.md).                                                                                                                              |

## 2. Controller concerns

Controllers keep their shared behaviour in concerns, not in a base class:

| Concern               | Function                                                      |
| --------------------- | ------------------------------------------------------------- |
| `FriendlyFinder`      | Finds a record by slug. Gives a 301 redirect for an old slug. |
| `FilterParamsBuilder` | Builds the filter parameters of the index pages.              |
| `ProductCatalogShow`  | Shared behaviour of the product and variant pages.            |
| `ProfileVisibility`   | Applies the profile visibility to one user.                   |
| `EventListing`        | Shared behaviour of the event lists.                          |
| `TokenUnsubscribe`    | Unsubscribe with a signed token.                              |

## 3. Presenters

Presenters are next to the models. They hold the display rules for the templates.

| Presenter                                                               | Wraps                                                                         |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| **`ItemPresenter`**                                                     | Base for gear with an optional product or variant (usually from a possession) |
| **`PossessionPresenter`**                                               | Current possession: prices, periods, gallery                                  |
| **`PreviousPossessionPresenter`**                                       | Possession in the previous collection                                         |
| **`ProductItemPresenter`**                                              | Catalog list row: paths, dates, list thumbnails                               |
| **`BookmarkPresenter`**                                                 | Polymorphic bookmark target                                                   |
| **`CustomProductPresenter`**                                            | Custom product with a UI like a possession                                    |
| **`SetupPossessionPresenter`**, **`CustomProduct*PossessionPresenter`** | Setup builder and related contexts                                            |
| **`ImagePresenter`**                                                    | Shared presentation of attachments                                            |

**`PossessionPresenterService`** selects a possession presenter by the ownership state and by the
link to a custom product.

## 4. Caching

The application caches:

- Taxonomy menus.
- Entity counts and event counts.
- Custom attribute definitions.
- The identifiers of the newest product items (see
  [catalog-listing-and-search.md](catalog-listing-and-search.md#5-newest-entries)).
- The home page counts.
- Some rendered legal or policy content.
- The ranked ids of Similar Products and Similar Brands (see
  [similar-products.md](similar-products.md)).
- The contribution guidelines page (see [contribution-guidelines.md](contribution-guidelines.md)).

## 5. Attachments

Active Storage stores:

- The image galleries of possessions and custom products.
- The avatar and the decorative banner of a user.
- Brand logos.

A purge of a possession image or a profile image can make an activity row.

## 6. Static pages

**`StaticController`** serves the changelog, about, imprint, privacy policy and the calculators. At
this time, there is one calculator: the adapter resistor calculator for an amplifier and headphones.
These pages use no domain model.

## 7. Background jobs

See [background-jobs.md](background-jobs.md).
