# HiFi Log

Architecture reference for the domain model, read-only SQL projections, and how the main concepts relate. Not a setup or operations guide.

## Conceptual overview

The catalog is built around **brands** and **products**. A **product** is the canonical model for a piece of gear (name, brand, categories, base specs). A **product variant** is a distinct line under that product (different finish, revision, regional model, etc.) that can override some fields while still inheriting the rest from the parent product.

**Possessions** represent a user's relationship to something in the catalog (or to a user-defined **custom product**): ownership, photos, purchase details, and optional links into **setups**. They always point at real database rows (`products`, `product_variants`, or `custom_products`), not at the unified listing abstraction.

**Product items** are not a third kind of catalog entity. They are a **read-only database view** that flattens each product and each of its variants into one row each, so lists and filters can treat "a row in the catalog" uniformly while still knowing whether that row is the base product or a variant. A second view of the same shape, **contribute product items**, adds the completeness information the contribution queues sort and filter on.

```mermaid
flowchart TB
  Category --> SubCategory
  SubCategory --> Product
  SubCategory --> CustomAttribute
  Brand --> Product
  Product --> ProductVariant
  Product --> ProductOption
  ProductVariant --> ProductOption
  User --> Possession
  Possession --> Product
  Possession --> ProductVariant
  Possession --> CustomProduct
  Possession --> ProductOption
  Product --> Bookmark
  ProductVariant --> Bookmark
  Brand --> Bookmark
  Event --> Bookmark
  User --> BookmarkList
  BookmarkList --> Bookmark
  Setup --> SetupPossession --> Possession
  Product --> Note
  ProductVariant --> Note
  User --> EventAttendee --> Event
  User -->|follower| UserFollow -->|followed| User
  User -->|blocker| UserBlock -->|blocked| User
  subgraph readonly [Read-only projection]
    ProductItem["ProductItem (view)"]
    ContributeProductItem["ContributeProductItem (view)"]
    SearchResult["SearchResult (view)"]
  end
  Product -.-> ProductItem
  ProductVariant -.-> ProductItem
  Product -.-> ContributeProductItem
  ProductVariant -.-> ContributeProductItem
  Product -.-> SearchResult
  ProductVariant -.-> SearchResult
  Brand -.-> SearchResult
```

## Taxonomy

**`Category`** and **`SubCategory`** form the gear taxonomy. Products, brands, and custom products each link to many subcategories. **`CustomAttribute`** definitions are also scoped to subcategories so structured fields only apply where relevant. Category trees are cached for navigation.

## Brand

**`Brand`** is the manufacturer or label (identity, country, lifecycle dates, description, optional logo). Brands link to subcategories and have many products. Catalog edits are versioned (see [Auditing](#auditing)).

A brand carries three names, each with one job:

- **`name`** — canonical identity, written the way the manufacturer writes it ("Bang & Olufsen"). Unique, and the `friendly_id` slug source. Used for JSON-LD `name` and wherever the brand has to be identified unambiguously.
- **`abbreviation`** — optional short form the brand is known by that is **not** part of its name: "B&O" for "Bang & Olufsen". Anything already contained in `name` is cleared in a `before_validation`, because search reaches those through `name` anyway — "fezz" prefix-matches "fezz audio", while "B&O" normalises to "bo", which "bang olufsen" neither starts with nor contains. That narrowing is what lets every display site render it without checking for repetition: whatever survives is never already visible in the name. Catalog views expose it as `brand_abbreviation` so listings don't join.
- **`legal_name`** — optional registered company name ("Bang & Olufsen A/S"). Shown in the facts list on the brand page; deliberately excluded from ranked search, since pg_search concatenates `against:` columns before computing trigram similarity and a long formulaic value dilutes every query.

Two accessors decide which form is rendered where:

- **`Brand#display_name`** — `abbreviation` if there is one, otherwise `name`. This is the default. It is what product and variant titles use, what product slugs are built from, and what lists, breadcrumbs and nav links show wherever there is room for only one string.
- **`Brand#seo_name`** — `"B&O (Bang & Olufsen)"` when an abbreviation exists, otherwise `name`. Used for the brand page title; the brand page `<h1>` renders the same pair as markup rather than a string.

Where there is room for both — brands index rows, brand search results, the sitemap — the abbreviation has priority, followed by `name`.

Product titles and slugs are built from `Brand#display_name`, and nothing on `Product` notices a change to either brand column. So `Brand` has an `after_update` calling `Product.resync_slugs_for` whenever `name` **or** `abbreviation` changes (`brand_naming_changed?`); it re-slugs the brand's products and preserves the old slugs in `friendly_id_slugs` so they 301. Adding an abbreviation to an existing brand therefore moves every product URL under it, which is intended: the title moves too.

## Product

A product belongs to one brand, has many variants, options, possessions, notes, and can be bookmarked. It links to many subcategories.

The product holds shared identity: brand, name, slug, categorization, and shared metadata. Options declared directly on the product represent product-level specs, as distinct from options declared on a specific variant.

## Product variant

A variant belongs to one product and has its own options, possessions, and notes. Where a variant doesn't override a field, it falls back to the parent product's value. Variants can also be bookmarked directly, alongside products, brands, and events.

## Catalog detail pages

**Product** and **ProductVariant** show pages share one orchestration path. For either entry type, the app loads:

- A **community image gallery** from possessions owned by users whose profiles allow catalog imagery (public always; logged-in-only when the viewer is signed in). Base-product pages use possessions with no variant; variant pages use that variant's possessions.
- **Contributors** from version history on the parent product.
- **Custom attributes** from the product (variants surface the parent's attribute set).
- When the viewer is signed in: their **possession**, **bookmark**, **note**, and **setups** scoped to that product or variant.

**`ProductCatalogShowService`** assembles this context for both show pages.

## Product option

`ProductOption` belongs to **either** a product **or** a variant (never both): structured spec lines (e.g. color, impedance). Possessions may optionally reference one to record the configuration the user actually has.

## Custom attributes (definitions vs values)

**Definitions** (`CustomAttribute`) are reusable fields tied to subcategories: label, input type, options, units, highlighted flag. Definitions are cached globally.

**Values** are stored directly on the product as a flexible set of key/value pairs, keyed by attribute label. Variants do not store their own values; wherever custom attributes are displayed for a variant, the parent product's values are shown instead.

### Naming a label

A label is a **disambiguator, not a namespace**. The subcategory join already scopes an attribute to where it applies, so a prefix that only restates the category buys nothing and costs something real: it forks one specification into two filter facets holding the same numbers in the same unit, which can then never be compared. The label names the measurement.

A prefix is only justified when two categories genuinely mean different things by the same word:

- **Different unit** — `headphone_sensitivity` (dB/mW) against `loudspeaker_sensitivity` (dB@1W/1m). Not comparable, so they must not share a range filter.
- **Different option set** — headphone enclosures (open / semi / closed) against speaker enclosures (sealed / ported / …).
- **Different question** — `cartridge_type` asks what a thing _is_, `supported_cartridge_types` asks what it _accepts_.

Where a prefix is warranted it comes from a closed list of **Category-level** words — `loudspeaker_`, `headphone_`, `turntable_`, `cartridge_`, `tonearm_`, `amplifier_`, `cable_`, `tube_`, `tape_` — never a subcategory name. Otherwise the bare term is used, chosen specifically enough that a future collision is unlikely (`bi_wiring`, not `wiring`).

### Labels and option values are i18n keys

Every surface that renders an attribute — product form, filter sidebar, spec list, the admin subcategory page — calls `t("custom_attribute_labels.#{label}")` **without a default**, so a label with no translation behind it does not degrade, it prints "translation missing" to the user. The same is true one level down for option values under `custom_attributes`, where a typo is worse still: products store the option _id_, so the broken key is invisible in the data and only surfaces on every product that chose it.

Definitions are admin-created data rows, so no test can enumerate what production holds; the only moment the two can be compared is the moment the row is written. `CustomAttribute` therefore validates both directions of that mapping. The practical consequence is a deploy order: **the translation ships before the attribute is created**, which is the same order `available_option_keys` already imposes by offering the admin a datalist of keys the locale file defines.

Units and inputs need the same translations, but `VALID_UNITS` and `VALID_INPUTS` are closed constants rather than data, so a test enumerates them instead of a validation.

### Units and conversion

Two units on one definition mean _the same quantity in the other system_, and both the filter and the display path assume they can convert between them. **`CustomAttribute::UNIT_CONVERSIONS`** is the single table saying which pairs those are and by what factor; `UNIT_EQUIVALENTS` derives the reverse direction so a display can show both readings from either side.

That table is also what makes a unit _storable_: filtering normalises a submitted range to the metric half of a pair and then matches on the stored `unit` string, so the metric half is the only spelling a value can be found under. A unit therefore only belongs in `UNIT_CONVERSIONS` once something genuinely converts to it, and a definition may only offer two units when those two are a pair listed there. `mm` is deliberately not paired with `in` for that reason — `in` already canonicalises to `cm`.

Two units are not always a pair: `loudspeaker_sensitivity` offers dB@1W/1m and dB@2.83V/1m, which are two different measurements with no factor between them, and the display shows a single reading.

The product form's unit radios declare **the unit the typed number is in**, not a display preference — the server normalises whatever it receives. So `entity_form.js` converts the displayed number whenever a radio is toggled: without that, switching kg to lb on a value nobody retyped redefines it rather than restating it, and switching back converts again instead of undoing. The rounding on both sides is eight decimal places, and they have to agree — coarser and a value typed as `2` comes back as `2.000001`, finer and it drifts on each pass. Where two units are not a convertible pair, toggling relabels and leaves the number alone, because relabelling is all it can honestly mean. (The filter sidebar's unit radios are not touched: those numbers are the visitor's own query, not a stored value.)

Because reads never convert, **values are normalised on write**: `Product` runs `CustomAttribute.normalize_units` before save whenever the specs changed, so a weight entered in pounds is stored in kilograms and "stored unit" and "canonical unit" mean the same thing everywhere downstream. It sits on the model rather than in the product form so ActiveAdmin, `ProductConversionService` and the console are covered too, and it is idempotent — a canonical unit converts to itself. Values written before it existed were rewritten once by `NormalizeStoredCustomAttributeUnits`, which finds them with a jsonpath predicate the GIN index can serve rather than scanning the catalogue.

For the `option` and `options` input types, the definition's `options` is a JSON object mapping a **numeric id** to an **i18n key** under `custom_attributes` in the locale files. Products store the id, never the key — so a mislabelled option can be renamed without touching a single product row. The admin editor upholds that split: ids are assigned automatically (always above the highest ever used, so a deleted id is never handed out again) and are not editable, while the key is picked from a datalist of what the locale file already defines. Removing an option asks for confirmation and states how many products still point at it, counted by **`CustomAttribute#option_usage_counts`** — one aggregate query narrowed by the GIN index on `products.custom_attributes`, not one count per option.

Exactly one shape of extra configuration applies per input type: `options` for `option`/`options`, `units` and `inputs` for `number`, neither for `boolean`. A `before_validation` clears whatever the current input type does not use, because the product form picks its control by inspecting `options` and then `inputs` rather than `input_type` — leftovers from a previous type would render the wrong widget. The admin form hides the group that doesn't apply and warns before a type switch discards anything.

**`CustomProduct`** does not participate in this system at all.

Filtering on catalog indexes uses the definitions applicable to the current category context.

## Catalog row views (`ProductItem`, `ContributeProductItem`)

`ProductItem` unions one row per product and one row per variant, distinguishing the two. Foreign keys elsewhere in the app still point at `Product` and `ProductVariant` directly — the view exists purely as a unified read surface, not as a new entity to relate to.

`ContributeProductItem` is a second view of the same shape, additionally carrying completeness information computed in SQL. Splitting it out keeps that extra computation off every catalog listing while letting the contribution queues sort and filter on completeness directly in the database.

Both models are read-only and share **`CatalogueProductRow`**, a concern covering brand and possession associations, list-thumbnail selection (base-product rows ignore variant-linked possessions), and image/subcategory-name preloading. `ProductItem` additionally supports name search and exposes the options that belong to each row. `ContributeProductItem` additionally exposes named gaps (missing release year, description, discontinued year, or specs) for the contribution queues to filter on, and carries its own variant-specific description so a variant lacking its own description doesn't disappear from that queue.

Use **Product** / **ProductVariant** to mutate data; use **ProductItem** for catalog listing and filters, **ContributeProductItem** for the contribution queues.

## Possession

A **user-owned instance** of catalog or custom gear, optionally tied to a `ProductOption`. Images attach to the possession. Product pages and base-product list thumbnails use possessions with no linked variant; variant surfaces use that variant's possessions.

**Setups** group possessions: `Setup` → `SetupPossession` → `Possession`. Setups are per-user, named, and may be **private** (affects public visibility and activity feed).

### Current vs previous collection

A flag separates the active collection from previous gear. Ownership spans are tracked as date ranges, and a timestamp records when an item moved from current to previous. Ownership changes drive corresponding **user activity** entries.

## Custom product

User-defined gear outside the shared catalog: categories, images, and exactly one linked **possession**. Does not use `Product`, `ProductVariant`, or `ProductItem`.

## Bookmark

Polymorphic saved reference (`Product`, `ProductVariant`, `Brand`, or `Event`)—not ownership. **`BookmarkList`** optionally groups bookmarks per user.

## Event

Dated occurrences with RSVPs via **`EventAttendee`**. Bookmarkable; included in global search projection for products/brands only, not events.

## Notes

Discussion text on a **product**, optionally scoped to a **variant** (one note per user per product/variant combination).

## Users, profiles, and dashboard

**`User`** accounts hold the collection, setups, bookmarks, notes, RSVPs, and profile media (avatar, decorative image).

**Profile visibility** (hidden, logged-in-only, visible) controls public discoverability and whether collection imagery from that user appears on catalog pages.

- **Public profile**: overview (collection preview, statistics, upcoming events, activity feed), full collection, previous gear, history, contributions.
- **Dashboard**: the signed-in owner's workspace—same domains plus a following-based activity feed, Community (following/followers), and settings pages for profile (visibility, images), notifications (follow emails, newsletter), and blocked users, alongside the Devise account form. The profile and notifications settings live under a dedicated **`Settings::`** namespace of controllers; blocked users has its own top-level controller.

## Following and blocking

**`UserFollow`** is a self-referential relationship (`follower` → `followed`). Creating one records an activity for the followed user and, if they've opted in to follow notifications, sends a notification email—at most once per follower/followed pair, so follow/unfollow toggling cannot spam the inbox. Unfollowing soft-hides the activity. Users cannot follow themselves or someone who blocks them; hidden profiles are excluded from follow feeds.

**`UserBlock`** (`blocker` → `blocked`) severs follow relationships in both directions on create. Blocks are not disclosed to the blocked user: the follow button stays visible and a follow attempt fails generically.

Follow notification emails support one-click unsubscribe, backed by **`FollowNotificationUnsubscribeService`** (signed token, parallel to the newsletter flow). The unsubscribe endpoints are public, token-authenticated controllers—**`FollowNotificationUnsubscribesController`** and **`NewsletterUnsubscribesController`**—that share the **`TokenUnsubscribe`** concern, separating a non-mutating confirmation step from the actual unsubscribe, and also supporting one-click unsubscribe requests initiated by mail clients. Because recipients may not be signed in, both are exempt from the privacy-policy gate.

## Authentication and admin

**Users** authenticate for the site (registration, confirmation, lockout). **Admin users** are a separate scope for back-office catalog management (ActiveAdmin). Community members can create and edit catalog entities; admins operate the full admin interface.

## Privacy policy

Published policy text has a **version** (requires re-acceptance) and a **content revision** (text-only updates). Users store which version they accepted and when. Sign-up requires acceptance; users on an outdated version must accept again or delete their account before using the app. Static/legal pages and account recovery remain available during that gate.

## User activity

Persisted **`UserActivity`** rows capture a verb, when it occurred, the affected catalog or social item, and enough metadata to render a feed entry without re-fetching it.

**Write path:** model callbacks feed into **`UserActivities::Recorder`** (with a **`PossessionSync`** helper reconciling ownership-related verbs).

**Read path:** **`UserActivityTimeline`** builds feed rows for the public overview and the owner dashboard. The dashboard feed is following-based: it merges the owner's activities with those of followed users (hidden profiles excluded) and shows the actor per row. A dedicated feed page paginates the same timeline at the database level.

Activity is generated across most of the domain: collection changes, custom products, setups (created, and made public/private), possessions added to or removed from a setup, event attendance, profile image changes, and new follows. Some verbs are recorded for auditing but excluded from public feeds; a small subset is only ever shown on the owner's own dashboard, never on public profiles.

The timeline applies a handful of presentation rules on top of raw chronological order: respecting setup privacy, avoiding redundant entries when a later event supersedes an earlier one, and grouping contiguous similar items.

A **backfill** task can rebuild activities from existing possessions, setups, RSVPs, and attachments where historical data allows.

## Search

**`SearchResult`** is a read-only view unioning products, variants, and brands with a unified name/slug shape for global search. **`ProductItem`** powers catalog browsing and category filters—separate concern from site-wide search.

## Auditing

**PaperTrail** versions **products**, **variants**, and **brands**. Per-record changelogs and a contributions summary show who edited the catalog over time.

## Completeness and contribution queues

Most catalog entries carry little more than a name and a brand, so _incomplete_ is the normal state rather than an error. The **`Completeness`** concern (included by `Brand`, `Product`, `ProductVariant`) describes how filled-in an entry is two ways: as **named gaps** for prompts on entry pages, and as a **0–100 score** for ordering the queues. Each including model weighs its own fields, roughly in proportion to how many surfaces a field feeds rather than by feel.

Rules worth knowing:

- **Inapplicable fields don't count against the score**, so nothing is permanently capped below 100% for something nobody can fix. A brand still trading is asked for a website but not a discontinuation year, and vice versa, and the two stay comparable.
- **Highlighted custom attributes** are the app's notion of a "key spec." They're scored as one group so categories with many and few applicable attributes remain comparable. Variants inherit the parent's attributes and cannot edit them, so specs are not part of a variant's own score.

**The score is computed twice**: once for display, and once so the database can sort and filter on it directly. The two are kept in sync by a dedicated test.

### Contribution queues

**`ContributeController`** is a task board for contributors: lists of entries each missing one specific, named gap. It is read-only and excluded from search indexing—every link leads into the existing brand or product edit forms.

Queues exist for brands with no products, brands missing a specific field, and products missing a specific field. All are optionally scoped to a `Category` and ordered by **descending completeness**—the nearly finished entries first, so a contributor is handed a small, finishable job instead of a blank form.

## Cross-cutting concerns

**Service objects** orchestrate catalog filtering, catalog detail (product/variant show) pages, statistics, caching of taxonomy/counts, possession→presenter selection, newsletter and follow-notification unsubscribe, and activity recording/backfill.

**Caching** covers taxonomy menus, entity counts, custom attribute definitions, event counts, and some rendered legal or policy content.

**Attachments** (Active Storage): possession and custom-product image galleries; user avatar and decorative banner; brand logos. Purges on possessions and profile images can emit activity rows.

**App news** announcements can be dismissed per user.

**Statistics** aggregate a user's possessions (current vs previous, costs, duration, categories) for dashboard and profile summaries. In the UI this section is called **Insights**; the code keeps the statistics naming.

**Security:** rate limits on auth, catalog writes, and follow/block mutations; content security policy; bot challenge on registration and password reset.

## Presenters

Presenters sit beside models and centralize display rules for templates.

| Presenter                                                               | Wraps                                                                |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------- |
| **`ItemPresenter`**                                                     | Base for gear with optional product/variant (usually via possession) |
| **`PossessionPresenter`**                                               | Current possession: prices, periods, gallery                         |
| **`PreviousPossessionPresenter`**                                       | Previous-collection possession                                       |
| **`ProductItemPresenter`**                                              | Catalog list row (paths, dates, list thumbnails)                     |
| **`BookmarkPresenter`**                                                 | Polymorphic bookmark target                                          |
| **`CustomProductPresenter`**                                            | Custom product with possession-like UI                               |
| **`SetupPossessionPresenter`**, **`CustomProduct*PossessionPresenter`** | Setup builder and related contexts                                   |
| **`ImagePresenter`**                                                    | Shared attachment presentation                                       |

**`PossessionPresenterService`** chooses among possession presenters by ownership state and custom-product linkage.

---

## Quick reference

| Concept                     | Mutable?  | Role                                                  |
| --------------------------- | --------- | ----------------------------------------------------- |
| `Category` / `SubCategory`  | Yes       | Taxonomy; scopes catalog and custom attributes        |
| `Brand`                     | Yes       | Manufacturer; products; bookmarks; search             |
| `Product`                   | Yes       | Shared catalog identity                               |
| `ProductVariant`            | Yes       | Variant-specific overrides                            |
| `ProductItem`               | No (view) | Unified catalog rows                                  |
| `ContributeProductItem`     | No (view) | Same rows plus completeness/specs, for contribute     |
| `SearchResult`              | No (view) | Global search rows                                    |
| `Possession`                | Yes       | Ownership, photos, setups; current vs previous        |
| `Setup`                     | Yes       | Named public/private gear groupings                   |
| `CustomProduct`             | Yes       | Off-catalog user gear                                 |
| `Bookmark` / `BookmarkList` | Yes       | Saved references; optional lists                      |
| `Event` / `EventAttendee`   | Yes       | Occurrences and RSVPs                                 |
| `ProductOption`             | Yes       | Spec lines on product or variant                      |
| `CustomAttribute`           | Yes       | Field definitions; values on `Product`                |
| `UserActivity`              | Yes       | Social/history feed                                   |
| `UserFollow`                | Yes       | Follower → followed relationship; drives feed & email |
| `UserBlock`                 | Yes       | Blocker → blocked; severs follows both ways           |
| `User`                      | Yes       | Account, visibility, policy acceptance, profile media |
