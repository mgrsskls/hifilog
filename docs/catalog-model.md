# Catalog model

This document describes the catalog entities: the taxonomy, brands, products, variants and
options. It also describes how the application assembles the product and variant pages. It uses
Simplified Technical English (ASD-STE100).

Related documents:

- Product series: [product-series.md](product-series.md)
- Custom attributes: [custom-attributes.md](custom-attributes.md)
- Catalog lists and search: [catalog-listing-and-search.md](catalog-listing-and-search.md)
- Similar Products and Similar Brands: [similar-products.md](similar-products.md)
- Related Products: [related-products.md](related-products.md)

## 1. Overview

```mermaid
flowchart TB
  Category --> SubCategory
  SubCategory --> Product
  SubCategory --> CustomAttribute
  Brand --> Product
  Brand --> ProductSeries
  ProductSeries -.->|optional| Product
  Product --> ProductVariant
  Product --> ProductOption
  ProductVariant --> ProductOption
```

| Model                      | Role                                                                             |
| -------------------------- | -------------------------------------------------------------------------------- |
| `Category` / `SubCategory` | Taxonomy. Scopes the catalog and the custom attributes.                          |
| `Brand`                    | The brand. Has products and series.                                              |
| `ProductSeries`            | Optional named product line of one brand.                                        |
| `Product`                  | Shared catalog identity: brand, name, slug, categories, custom attribute values. |
| `ProductVariant`           | Smaller edition of a product under the same name. Overrides some fields.         |
| `ProductOption`            | A configuration in which a product or variant is sold.                           |
| `CustomAttribute`          | Definition of a field for a value of a product. The values are on `Product`.     |

PaperTrail versions products, variants, brands and product series. Per-record changelogs and a
contributions summary show who edited the catalog. See [8. Changelog](#8-changelog).

## 2. Taxonomy

`Category` and `SubCategory` form the gear taxonomy. Products, brands and custom products each
link to many sub categories. `CustomAttribute` definitions are also scoped to sub categories, so a
custom attribute applies only where it is relevant. The application caches the category tree
for the navigation.

A sub category has a `slug` and an `identifier`:

- **`slug`** comes from `name`. FriendlyId makes a new slug when the name changes. This is
  correct for a URL.
- **`identifier`** comes from the name one time, on create. After that, it does not change.
  [Related Products](related-products.md) refers to sub categories by `identifier`. Thus, a new
  display name does not remove a pairing edge.

## 3. Brand

`Brand` is the brand or label: identity, country, lifecycle dates, description and optional
logo. A brand links to sub categories and has many products. Users can bookmark and follow a
brand (see [brand-follows.md](brand-follows.md)).

The website of a brand must be a full `http` or `https` address with a dot in the host. The brand
page shows the website as a link. Thus, a value with another scheme, for example `javascript:`,
must never get into the database.

### 3.1 Three names

A brand has three names. Each name has one function:

- **`name`**: the canonical identity, written as the brand writes it ("Bang & Olufsen"). It is
  unique and it is the source of the `friendly_id` slug. JSON-LD `name` uses it. Use it when the
  brand must be identified without doubt.
- **`abbreviation`**: optional short form that is **not** part of the name ("B&O"). A
  `before_validation` clears a value that `name` already contains. Thus, the abbreviation never
  repeats the name, and the views do not need a check for repetition. The catalog views give it
  as `brand_abbreviation`, so lists do not need a join.
- **`legal_name`**: optional registered company name ("Bang & Olufsen A/S"). The brand page shows
  it in the facts list, and the brand filter can use it. Ranked search does not use it.

### 3.2 Which name is shown

- **`Brand#display_name`** gives `abbreviation` if there is one, and `name` if not. This is the
  default. Product and variant titles, product slugs, lists, breadcrumbs and navigation links use
  it.
- **`Brand#seo_name`** gives `"B&O (Bang & Olufsen)"` when there is an abbreviation, and `name` if
  not. The brand page title uses it. The `<h1>` of the brand page shows the same pair as markup.

Where there is space for the two names (rows of the brands index, brand search results, the
sitemap), the abbreviation comes first, then `name`.

### 3.3 Product slugs follow the brand name

Product titles and slugs come from `Brand#display_name`. `Product` does not see a change of the
brand columns. For this reason, `Brand` has an `after_update` that calls
`Product.resync_slugs_for` when `name` **or** `abbreviation` changes (`brand_naming_changed?`).
This gives new slugs to the products of the brand. The old slugs stay in `friendly_id_slugs`, so
an old URL gives a 301 redirect. When you add an abbreviation to a brand, all product URLs of the
brand change. This is intended, because the titles change too.

## 4. Product

A product belongs to one brand. It has many variants, options, possessions and notes. It links to
many sub categories. Users can bookmark it.

The product holds the shared identity: brand, name, slug, categories and shared metadata. It also
holds the custom attribute values (see [custom-attributes.md](custom-attributes.md)). Options
on the product apply to the product. Options on a variant apply only to that variant.

A product has zero or one series. The series has an effect on the slug and the title. See
[product-series.md](product-series.md).

## 5. Product variant

A variant belongs to one product. It has its own options, possessions and notes. When a variant
does not override a field, the value of the parent product applies. Users can bookmark a variant.

### 5.1 A variant never has different custom attribute values

A variant is a **smaller edition under the same name**: a finish, a limited edition, a regional
model number. When the measured behaviour is different (a Mk II, a second impedance), it is **a
separate product**. The design of custom attributes depends on this rule.

The rule has two results. Both are correct:

- The `product_items` view gives `products.custom_attributes` to the variant rows too. A variant
  has the custom attribute values of its parent because it cannot have other values. Thus, a filter
  on a custom attribute gives the product _and_ its variants.
- The completeness score of a variant does not include custom attributes, because a variant has no
  custom attribute values to fill in.

The application does not enforce the rule. When a contributor breaks the rule, nothing shows it.
For example, a variant for a second impedance shows the impedance of the parent and the filter
finds it with that impedance. The contribution guidelines state the rule (section 3.1 of
`/contribute/guidelines`, and first in the summary on the variant form).

A Mk II as a separate product has no link to the product that it replaced. There is no relation
between products at this time. This is the main reason why contributors want to break the rule. A
simple succession link between products can solve this problem without custom attribute values on variants.

`ProductConversionService` converts a product into a variant of another product, and back. It
never moves an entry to a different brand.

## 6. Product option

`ProductOption` belongs to **a product or a variant**, never to the two. It is one of the
configurations in which the product is _sold_: colour, finish, cable length. Each option can have
its own `model_no`. A possession can refer to one option to record the configuration that the user
has.

### 6.1 Option or custom attribute?

The answer depends on what the value describes:

- A **custom attribute** is one value that is true for _every unit_ of the product: weight,
  impedance, driver type. It describes the model. The catalog filters use it.
- A **product option** is one of many configurations in which the product is _sold_. It changes
  for each unit that a person buys and usually has its own part number. The possession records
  which option an owner has. The product does not.

Thus, the conductor material of a cable is an attribute and its length is an option. The same
cable in 1 m and 2 m is one model in two configurations. The same test puts loudspeaker finish and
cable termination on the option side.

When a brand sells the versions as different product lines, and not as configurations of one
product, use a `ProductVariant` (see [5](#5-product-variant)).

## 7. Product and variant pages

The show pages of `Product` and `ProductVariant` use the same path.
**`ProductCatalogShowService`** assembles the context for the two pages:

- A **community image gallery** from the possessions of users whose profiles allow catalog images.
  Public profiles always, profiles for signed-in users only when the viewer is signed in. A
  product page uses the possessions with no variant. A variant page uses the possessions of that
  variant.
- **Contributors** from the version history of the parent product.
- **Custom attributes** from the product. A variant shows the attributes of its parent.
- **Similar products** ([similar-products.md](similar-products.md)) and **related products**
  ([related-products.md](related-products.md)).
- **More from this series**: the other products of the series (`SeriesProducts`, see
  [product-series.md](product-series.md)).
- When the viewer is signed in: the **possession**, **bookmark**, **note** and **setups** of the
  viewer for that product or variant.

The meta block at the end of the sidebar (completeness prompt, "Edit" and "Changelog" links,
contributors) is one partial, **`shared/_entity_meta`**. The brand, product, variant and product
series pages use it. `ApplicationHelper#contributor_links` shows the contributors. For a hidden
profile, it shows the name without a link.

## 8. Changelog

PaperTrail versions products, variants, brands and product series. Each of these entities has a
changelog page. The page shows the versions of the entity, newest first. The product series
changelog also shows the products that were added or removed (see
[product-series.md](product-series.md#63-changelog-and-contributors)).

PaperTrail records only the columns of a model. Some data is in associations:

| Data                                 | Key in `versions.association_changes` |
| ------------------------------------ | ------------------------------------- |
| Sub categories of a product or brand | `sub_category_ids`                    |
| Options of a product or of a variant | `product_options`                     |
| Logo of a brand                      | `logo`                                |
| Conversion from a product or variant | `converted_from`                      |

`versions.association_changes` is a JSON column. It has the same form as `object_changes`: one
key for each association, with the old and the new value. The changelog and the admin activity
page merge the two columns. The versions from before this column do not have these changes. There
is no data to backfill.

### 8.1 When the version is recorded

- When only an association changes, no column changes. PaperTrail then does not record an update
  version. Thus the model records the update version itself (`record_update_version` in
  `AssociationVersioning`). It forces a version when an association changed.
- `Brand`, `Product` and `ProductVariant` declare `has_paper_trail on: []` and add the PaperTrail
  callbacks after their associations. The associations save their new records first, so the
  create version has the sub categories and the options of the new record.
- A touch does not record a version. PaperTrail records every touch as a version without changes,
  and a touch comes from a save of another record: a product touches its brand and its series, a
  variant touches its product. These versions made the author of the other record a contributor.
  Thus no model calls `paper_trail.on_touch`, and `ProductSeries` has
  `on: [:create, :update, :destroy]`.
- `bin/rails versions:delete_touch_versions` deletes the touch versions from before this change.
  Run it one time after the deploy.
- Contributors are the users with versions on the record itself. A product editor is not a
  contributor of the brand, and a variant editor is not a contributor of the product. The one
  exception is the product series (see
  [product-series.md](product-series.md#63-changelog-and-contributors)).

### 8.2 Sub categories

- The value is the list of the sub category ids, sorted. The changelog shows the current names.
  A deleted sub category shows as "Deleted".
- A change to the sub categories of a saved product or brand goes to the database at once, before
  the save. The model keeps the old ids at the first change and writes the change into the version
  of the next save (`VersionedSubCategories`).
- A product save adds the sub categories of the product to its brand. This change gets no brand
  version, because the user did not edit the brand (`without_sub_category_versioning`).

### 8.3 Options

- The value is the list of the options as text, "Option (model no.)", sorted. The text, not the
  ids: an option has no page, and a deleted option must stay readable in the changelog.
- The product and variant forms write the options directly, before the save of the product or
  variant. Before they write, they call `remember_product_options`. The next save compares the
  options in the database with the kept list.
- On an update, the option writes and the save are in one transaction
  (`ProductOptionsAssignable#save_with_product_options`). When the save fails, the options do not
  change either.
- On a create, the options are saved together with the new product or variant, so the create
  version has them.
- ActiveAdmin saves an option without a save of its product or variant. The ActiveAdmin resource
  records the version of the old and of the new owner (`record_product_options_version`).
- A conversion between product and variant moves the options with `update_all`. The conversion
  version records them (see [8.5](#85-conversion-between-product-and-variant)).

### 8.4 Brand logo

- The value is the file name of the old and of the new logo. `nil` is no logo. Thus a new logo is
  `[nil, "new.png"]`, a replaced logo is `["old.png", "new.png"]` and a removed logo is
  `["old.png", nil]`.
- The version stores the file names only. Active Storage deletes the old image, so the changelog
  can not show it.
- Only ActiveAdmin can change the logo.

### 8.5 Conversion between product and variant

`ProductConversionService` creates a new record and deletes the original. The versions of the
original move to the new record, so the history continues there.

- After the conversion, the new record gets one more version (`record_version_with`). It has
  `converted_from`, for example `[nil, 'Product "Feliks Audio Elise"']`, and the options that
  came along. The changelog shows it as one line: "Converted from Product "Feliks Audio Elise"".
- The value is text, because the original is deleted.
- The target product of a conversion into a variant gets no version. The variant has its own
  changelog.
- The conversion version does not change the series. Thus it is not an entry in the series
  changelog.
